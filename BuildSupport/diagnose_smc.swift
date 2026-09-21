import Foundation
import SMCKit
import smc_power

do {
    let keys: [FourCharCode] = ["CH0B", "CH0C", "CHTE", "CH0I", "CHIE", "bfF0", "bfD0", "bfE0"]
    for key in keys {
        do {
            let info = try SMCKit.shared.getKeyInformation(key)
            print("key=\(key.toString()) type=\(info.type.toString()) size=\(info.size)")
            if ["bfF0", "bfD0", "bfE0"].contains(key.toString()) {
                print("value=\(try SMCKit.shared.readData(key).map { String(format: "%02x", $0) }.joined())")
            }
        } catch {
            print("key=\(key.toString()) error=\(error)")
        }
    }
    print("CH0C=\(try SMCKit.shared.isKeyFound("CH0C"))")
    print("CHTE=\(try SMCKit.shared.isKeyFound("CHTE"))")
    print("CH0I=\(try SMCKit.shared.isKeyFound("CH0I"))")
    print("CHIE=\(try SMCKit.shared.isKeyFound("CHIE"))")

    let battery = try SMCBattery.probe()
    if let voltage = try? SMCAdapter.getVoltage(), let current = try? SMCAdapter.getCurrent() {
        print(String(format: "adapter=%.2fV %.3fA %.2fW", voltage, current, voltage * current))
    }
    if let voltage = try? SMCBattery.getVoltage(), let current = try? SMCBattery.getCurrent() {
        print(String(format: "battery=%.2fV %.3fA %.2fW", voltage, current, voltage * current))
    }
    print("chargingControl=\(battery.capabilities.inhibitChargeControl)")
    print("adapterControl=\(battery.capabilities.forceDischargeControl)")
    print("chargingBackend=\(battery.chargingControlKey)")

    if battery.capabilities.inhibitChargeControl {
        print("chargingInhibited=\(try battery.getChargingInhibited())")
    }
    if battery.capabilities.forceDischargeControl {
        print("forceDischarging=\(try battery.getForceDischarging())")
    }
} catch {
    print("diagnosticError=\(error.localizedDescription)")
    exit(1)
}
