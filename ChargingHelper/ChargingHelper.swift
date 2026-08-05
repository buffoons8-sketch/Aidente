import Foundation
import AidenteShared
import os.log
import smc_power

private enum Constants {
    static let subsystem = "com.aidente.app.control"
}

final class ChargingHelper: NSObject, AidenteControlProtocol {
    private let battery: SMCBattery
    private let adapter: SMCAdapter
    private let logger = Logger(
        subsystem: Constants.subsystem,
        category: "ChargingHelper"
    )
    private(set) var resetOnDisconnect = true

    init(battery: SMCBattery, adapter: SMCAdapter) {
        self.battery = battery
        self.adapter = adapter
        super.init()
        logger.info(
            "Initialized (charging=\(battery.capabilities.inhibitChargeControl), discharge=\(battery.capabilities.forceDischargeControl), magSafe=\(adapter.capabilities.magSafeControl))"
        )
    }

    func ping(reply: @escaping @Sendable (Bool, String?) -> Void) {
        reply(true, nil)
    }

    func manageBatteryCharging(enabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void) {
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

    func manageExternalPower(enabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void) {
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

    func manageMagsafeLED(target: UInt8, reply: @escaping @Sendable (Bool, String?) -> Void) {
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

    func setResetOnDisconnect(_ enabled: Bool) {
        resetOnDisconnect = enabled
        logger.info("Reset on disconnect: \(enabled)")
    }

    // Preserving state across disconnects is only meant to keep the charge
    // pause. A preserved force discharge would drain the battery to empty
    // with the adapter plugged in, so it is always cleared.
    func clearForceDischarge() {
        guard battery.capabilities.forceDischargeControl else { return }
        do {
            if try battery.getForceDischarging() {
                try battery.setForceDischarging(false)
                logger.info("Force discharge cleared")
            }
        } catch {
            logger.error("clearForceDischarge failed: \(error.localizedDescription)")
        }
    }

    func resetToDefaults() {
        do {
            if battery.capabilities.inhibitChargeControl {
                try battery.setChargingInhibited(false)
            }
            if battery.capabilities.forceDischargeControl {
                try battery.setForceDischarging(false)
            }
            if adapter.capabilities.magSafeControl {
                try adapter.setMagSafeLEDState(.reset)
            }
            logger.info("SMC keys reset to defaults")
        } catch {
            logger.error("resetToDefaults failed: \(error.localizedDescription)")
        }
    }
}
