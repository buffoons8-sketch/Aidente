import Foundation
import AidenteShared
import os.log
import smc_power
import IOKit
import IOKit.pwr_mgt
import Darwin
import SMCKit

private enum Constants {
    static let subsystem = "com.aidente.app.control"
    // IOMessage.h: iokit_common_msg values. The SDK's C function-like macros
    // are not imported by Swift.
    static let canSleep: UInt32 = 0xe0000270
    static let willSleep: UInt32 = 0xe0000280
    static let willNotSleep: UInt32 = 0xe0000290
    static let didWake: UInt32 = 0xe0000300
}

final class ChargingHelper: NSObject, AidenteControlProtocol {
    private var battery: SMCBattery
    private let adapter: SMCAdapter
    private let logger = Logger(
        subsystem: Constants.subsystem,
        category: "ChargingHelper"
    )
    private(set) var resetOnDisconnect = true
    private let queue = DispatchQueue(label: "com.aidente.app.control.power")
    private var policy: ChargingPowerPolicy?
    private var firmwarePolicy = FirmwarePowerPolicy()
    private var hasControlledPower = false
    private var sleeping = false
    private var clients = 0
    private var lastClientPID: pid_t?
    private var disconnectGeneration = 0
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var powerConnection: io_connect_t = 0
    private var watchdog: DispatchSourceTimer?
    private let controlDefaults = UserDefaults(suiteName: "com.aidente.app.control") ?? .standard
    private let firmwareSnapshotKey = "firmwareLimitBeforeAidente"

    init(battery: SMCBattery, adapter: SMCAdapter) {
        self.battery = battery
        self.adapter = adapter
        super.init()
        logger.info(
            "Initialized (charging=\(battery.capabilities.inhibitChargeControl), discharge=\(battery.capabilities.forceDischargeControl), magSafe=\(adapter.capabilities.magSafeControl))"
        )
        logger.notice("CONTROL_KEYS charging=\(battery.chargingControlKey, privacy: .public) discharge=\(battery.dischargeControlKey, privacy: .public)")
        startPowerMonitoring()
    }

    private func startPowerMonitoring() {
        powerConnection = IORegisterForSystemPower(
            Unmanaged.passUnretained(self).toOpaque(), &notificationPort,
            { context, _, message, argument in
                guard let context else { return }
                let helper = Unmanaged<ChargingHelper>.fromOpaque(context).takeUnretainedValue()
                helper.powerEvent(message, argument: argument)
            }, &notifier
        )
        if powerConnection != 0, let notificationPort {
            IONotificationPortSetDispatchQueue(notificationPort, queue)
        } else {
            logger.error("POWER_MONITOR_REGISTRATION_FAILED")
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 15, repeating: 15, leeway: .seconds(3))
        timer.setEventHandler { [weak self] in self?.reconcile(reason: "watchdog") }
        timer.resume()
        watchdog = timer
    }

    // Runs on the same serial queue as every SMC write. Acknowledge sleep only
    // after the write and readback, not after enqueueing an asynchronous XPC call.
    private func powerEvent(_ message: UInt32, argument: UnsafeMutableRawPointer?) {
        switch message {
        case Constants.canSleep:
            IOAllowPowerChange(powerConnection, Int(bitPattern: argument))
        case Constants.willSleep:
            sleeping = true
            policy?.sleeping = true
            reconcile(reason: "willSleep")
            IOAllowPowerChange(powerConnection, Int(bitPattern: argument))
        case Constants.didWake, Constants.willNotSleep:
            sleeping = false
            // Keep the sleep hold until the app submits a fresh policy. A dark
            // wake must not resume charging from a stale pre-sleep percentage.
            do { battery = try SMCBattery.probe() }
            catch { logger.error("Wake capability probe failed: \(error.localizedDescription, privacy: .public)") }
            reconcile(reason: "didWake")
            queue.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.reconcile(reason: "wakeRecheck")
            }
            queue.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.resetAfterDisconnectIfNeeded()
            }
        default: break
        }
    }

    func clientConnected(pid: pid_t) {
        queue.sync {
            clients += 1
            disconnectGeneration += 1
            lastClientPID = pid
        }
    }

    func clientDisconnected() {
        queue.async {
            self.clients = max(0, self.clients - 1)
            self.disconnectGeneration += 1
            let generation = self.disconnectGeneration
            self.queue.asyncAfter(deadline: .now() + 5) {
                guard self.clients == 0, generation == self.disconnectGeneration else { return }
                // A transient XPC interruption at sleep must not undo the hold.
                self.resetAfterDisconnectIfNeeded()
            }
        }
    }

    private func resetAfterDisconnectIfNeeded() {
        guard clients == 0, resetOnDisconnect, !sleeping, hasControlledPower else { return }
        if let pid = lastClientPID, kill(pid, 0) == 0 || errno == EPERM {
            return // The GUI is alive but suspended or reconnecting.
        }
        resetOnQueue()
    }

    func applyPowerPolicy(charging: Bool, adapter: Bool, managed: Bool,
                          stopWhileSleeping: Bool, resetOnDisconnect: Bool,
                          chargeCeiling: Int, rechargeBelow: Int,
                          reply: @escaping @Sendable (Bool, String?) -> Void) {
        queue.async {
            guard (1...100).contains(chargeCeiling), rechargeBelow >= 0,
                  rechargeBelow < chargeCeiling else {
                reply(false, "Invalid firmware charge interval")
                return
            }
            var request = ChargingPowerPolicy()
            request.charging = charging
            request.adapter = adapter
            request.managed = managed
            request.stopWhileSleeping = stopWhileSleeping
            request.sleeping = self.sleeping
            request.chargeCeiling = chargeCeiling
            request.rechargeBelow = rechargeBelow
            self.policy = request
            self.hasControlledPower = true
            self.resetOnDisconnect = resetOnDisconnect
            do {
                if managed && stopWhileSleeping && self.powerConnection == 0 {
                    throw NSError(domain: "AidenteControl", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "无法注册系统睡眠通知，请修复控制服务"
                    ])
                }
                try self.applyEffectivePolicy()
                reply(true, nil)
            } catch {
                self.logger.error("POWER_POLICY_FAILED \(error.localizedDescription, privacy: .public)")
                if case SMCError.notPrivileged = error {
                    reply(false, "FIRMWARE_ACCESS_DENIED: system firmware denied charge-control access")
                } else {
                    reply(false, error.localizedDescription)
                }
            }
        }
    }

    private func applyEffectivePolicy() throws {
        guard let policy else { return }
        let target = policy.effective
        if battery.usesFirmwareChargeLimit {
            let controller = FirmwareChargeLimitController(registers: SMCFirmwareLimitRegisters())
            if target.adapter, battery.capabilities.forceDischargeControl,
               try battery.getForceDischarging() {
                try battery.setForceDischarging(false)
            }
            if policy.managed {
                // A root-owned preference survives daemon upgrades and crashes;
                // turning management off must restore the user's original limit.
                if controlDefaults.data(forKey: firmwareSnapshotKey) == nil {
                    let snapshot = try JSONEncoder().encode(controller.read())
                    controlDefaults.set(snapshot, forKey: firmwareSnapshotKey)
                    guard controlDefaults.synchronize() else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                }
                let percentage = try SMCBattery.firmwarePercentageExact()
                let externalConnected = try SMCBattery.externalPowerConnected()
                let previous = try controller.read()
                switch firmwarePolicy.target(policy: policy, percentage: percentage,
                                             externalConnected: externalConnected) {
                case .unlimited:
                    var unlimited = previous
                    unlimited.activation = 0
                    try controller.replace(with: unlimited)
                case .interval(let lower, let upper):
                    try controller.set(lower: lower, upper: upper)
                }
                let applied = try controller.read()
                if applied != previous {
                    let rawPercentage = String(format: "%.4f", percentage)
                    logger.notice("FIRMWARE_INTERVAL_APPLIED raw=\(rawPercentage, privacy: .public) lower=\(applied.lower) upper=\(applied.upper) activation=\(applied.activation) sleeping=\(policy.sleeping) chargingRequested=\(target.charging) externalConnected=\(externalConnected)")
                }
            } else {
                try restoreFirmwareLimit()
            }
            if battery.capabilities.forceDischargeControl {
                if try battery.getForceDischarging() == target.adapter {
                    try battery.setForceDischarging(!target.adapter)
                }
                guard try battery.getForceDischarging() == !target.adapter else {
                    throw SMCBatteryError.stateVerificationFailed
                }
            } else if !target.adapter {
                throw SMCBatteryError.unsupportedCapability
            }
        } else {
            try battery.applyPowerState(charging: target.charging, adapter: target.adapter)
        }
    }

    private func restoreFirmwareLimit() throws {
        guard let data = controlDefaults.data(forKey: firmwareSnapshotKey) else { return }
        let original = try JSONDecoder().decode(FirmwareChargeLimitState.self, from: data)
        try FirmwareChargeLimitController(registers: SMCFirmwareLimitRegisters()).replace(with: original)
        controlDefaults.removeObject(forKey: firmwareSnapshotKey)
        controlDefaults.synchronize()
    }

    private func reconcile(reason: String) {
        guard let policy else { return }
        do {
            try applyEffectivePolicy()
            if reason != "watchdog" {
                logger.notice("POWER_EVENT \(reason, privacy: .public) charging=\(policy.effective.charging) adapter=\(policy.effective.adapter)")
            }
        } catch {
            logger.error("POWER_RECONCILE_FAILED \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func ping(reply: @escaping @Sendable (Bool, String?) -> Void) {
        reply(true, nil)
    }

    func manageBatteryCharging(enabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void) {
        queue.sync {
        hasControlledPower = true
        do {
            guard battery.capabilities.inhibitChargeControl else {
                reply(false, "当前设备不支持充电控制")
                return
            }
            let currentlyInhibited = try battery.getChargingInhibited()
            if currentlyInhibited != !enabled {
                try battery.setChargingInhibited(!enabled)
                logger.debug("SMC set charging inhibited to: \(!enabled)")
            }
            let appliedValue = try battery.getChargingInhibited()
            guard appliedValue == !enabled else {
                reply(false, "SMC 没有接受充电暂停状态")
                return
            }
            reply(true, nil)
        } catch {
            logger.error("manageBatteryCharging failed: \(error.localizedDescription)")
            reply(false, error.localizedDescription)
        }
        }
    }

    func manageExternalPower(enabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void) {
        queue.sync {
        hasControlledPower = true
        do {
            guard battery.capabilities.forceDischargeControl else {
                reply(false, "当前设备不支持适配器控制")
                return
            }
            let currentlyDischarging = try battery.getForceDischarging()
            if currentlyDischarging != !enabled {
                try battery.setForceDischarging(!enabled)
                logger.debug("SMC set force discharging to: \(!enabled)")
            }
            let appliedValue = try battery.getForceDischarging()
            guard appliedValue == !enabled else {
                reply(false, "SMC 没有接受适配器控制状态")
                return
            }
            reply(true, nil)
        } catch {
            logger.error("manageExternalPower failed: \(error.localizedDescription)")
            reply(false, error.localizedDescription)
        }
        }
    }

    func manageMagsafeLED(target: UInt8, reply: @escaping @Sendable (Bool, String?) -> Void) {
        queue.sync {
        do {
            guard adapter.capabilities.magSafeControl else {
                reply(false, "当前设备不支持 MagSafe 指示灯控制")
                return
            }
            guard let ledState = MagSafeLEDState(rawValue: target) else {
                reply(false, "无效的 MagSafe 指示灯状态：\(target)")
                return
            }
            let currentState = try adapter.getMagSafeLEDState()
            if currentState != ledState {
                try adapter.setMagSafeLEDState(ledState)
                logger.debug("SMC MagSafe LED set to: \(ledState.rawValue)")
            }
            reply(true, nil)
        } catch {
            logger.error("manageMagsafeLED failed: \(error.localizedDescription)")
            reply(false, error.localizedDescription)
        }
        }
    }

    func setResetOnDisconnect(_ enabled: Bool) {
        queue.sync {
        resetOnDisconnect = enabled
        logger.info("Reset on disconnect: \(enabled)")
        }
    }

    func resetToDefaults() {
        queue.sync { resetOnQueue() }
    }

    func restoreDefaults(reply: @escaping @Sendable (Bool, String?) -> Void) {
        queue.async {
            do {
                try self.restoreOnQueue()
                reply(true, nil)
            } catch {
                reply(false, error.localizedDescription)
            }
        }
    }

    private func resetOnQueue() {
        do { try restoreOnQueue() }
        catch { logger.error("resetToDefaults failed: \(error.localizedDescription)") }
    }

    private func restoreOnQueue() throws {
        policy = nil
        firmwarePolicy.reset()
        if battery.capabilities.forceDischargeControl {
            try battery.setForceDischarging(false)
        }
        if battery.usesFirmwareChargeLimit {
            try restoreFirmwareLimit()
        } else if controlDefaults.data(forKey: firmwareSnapshotKey) != nil {
            throw SMCBatteryError.unsupportedCapability
        } else if battery.capabilities.inhibitChargeControl {
            try battery.setChargingInhibited(false)
        }
        if adapter.capabilities.magSafeControl {
            do { try adapter.setMagSafeLEDState(.reset) }
            catch { logger.warning("LED reset failed after restoring power: \(error.localizedDescription)") }
        }
        logger.info("SMC keys reset to defaults")
        hasControlledPower = false
    }
}
