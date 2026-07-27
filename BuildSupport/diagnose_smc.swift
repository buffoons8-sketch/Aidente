import Foundation
import SMCKit
import smc_power

do {
    print("CH0C=\(try SMCKit.shared.isKeyFound("CH0C"))")
    print("CHTE=\(try SMCKit.shared.isKeyFound("CHTE"))")
    print("CH0I=\(try SMCKit.shared.isKeyFound("CH0I"))")
    print("CHIE=\(try SMCKit.shared.isKeyFound("CHIE"))")

    let battery = try SMCBattery.probe()
    print("chargingControl=\(battery.capabilities.inhibitChargeControl)")
    print("adapterControl=\(battery.capabilities.forceDischargeControl)")

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
