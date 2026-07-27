# iadente

iadente is an independent, open-source macOS menu bar app for Apple Silicon
MacBooks. It monitors battery and power data and can manage low-level charging
controls through an explicitly approved privileged helper.

Version 0.4.1 follows the macOS system language by default and also offers
explicit Chinese/English choices. It merges live battery percentage and
charge-limit adjustment into one interactive battery track, and uses an
adaptive power-flow diagram for live power data.

This project does not contain AlDente Pro code, assets, activation logic, or
modified binaries. It implements similar battery-care workflows from public
behavior descriptions and GPL-compatible open-source foundations.

## Requirements

- Apple Silicon MacBook
- macOS 14 or later
- Administrator approval for charge-control features

Monitoring works without the privileged helper. Unsupported controls are
disabled rather than forced.

## Features

- Configurable charge limit
- Sailing range to avoid micro-charging
- Automatic or one-time discharge
- Top Up to 100%
- Persistent multi-stage calibration:
  - charge to 100%
  - discharge to the configured low level
  - recharge to 100%
  - hold at full charge
  - restore the saved charge limit
- Heat protection with five-minute hysteresis
- Hardware and macOS battery percentages
- Battery health, cycle count, temperature, voltage, current, and power
- Power-flow visualization
- MagSafe LED states when supported
- Pause charging while sleeping
- Optional charging-state preservation after the app quits
- Prevent sleep until the charge limit is reached
- Scheduled charge limits, Top Up, calibration, pause, and discharge tasks
- Login launch and customizable menu-bar/dashboard display
- Follow-system language mode plus instant Chinese/English switching
- Apple Shortcuts-compatible URL actions

## Install

Drag `iadente.app` to `/Applications`, open it, then enable charge management in
Settings → Charging. macOS may ask you to approve the background helper in
System Settings → General → Login Items.

The distributed local build is ad-hoc signed, not Apple-notarized. If Finder
blocks the first launch, right-click the app and choose Open.

## Shortcuts URLs

Use Shortcuts → Open URLs with one of:

```text
iadente://set-limit?value=80
iadente://top-up
iadente://calibrate
iadente://pause
iadente://discharge?value=70
iadente://resume
```

## Build from source

The repository includes fixed copies of its open-source dependencies so it can
build without downloading packages:

```text
chmod +x BuildSupport/build_app.sh
BuildSupport/build_app.sh
```

The output is `Dist/iadente.app`.

## Safety and uninstall

Before uninstalling, turn off Manage Charging in Settings → Charging. This
unregisters the privileged helper and restores the default charge, adapter, and
MagSafe LED states.

Low-level SMC controls are private interfaces and may change in future macOS
versions. Use at your own risk and keep a charger available during calibration.

## License and attribution

iadente is licensed under GPL-3.0 because it is based on the GPL-3.0 Stasis
project. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

AlDente is a trademark of its respective owner. iadente is independent and is
not affiliated with, endorsed by, or distributed by AppHouseKitchen.
