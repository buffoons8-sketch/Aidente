# Aidente

Aidente is an independent, open-source macOS menu bar app for Apple Silicon
MacBooks. It monitors battery and power data and can manage low-level charging
controls through an explicitly approved privileged helper.

Version 6.0 improves the visibility of live voltage and current readings by
using a brighter source-matched color and stronger typography in the power-flow
diagram. It also includes the diagnostics center, long-term battery-capacity
history, active charger specification, and direct dashboard protection toggles
introduced after the previous public release.

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
- One-decimal battery-health estimate based on full versus design capacity
- Design, current, and estimated full-charge capacity in mAh
- Long-term capacity history from first run onward with one point per day
- 30-day, one-year, and all-time capacity-history chart ranges
- Battery health, cycle count, temperature, voltage, current, and power
- Power-flow visualization
- Live adapter and battery voltage/current readings inside the power-flow nodes
- Compact active charger protocol/voltage/current/wattage display in the charge-limit card
- Direct dashboard toggles for heat protection, sleep pause, and sailing
- MagSafe LED states when supported
- Pause charging while sleeping
- Optional charging-state preservation after the app quits
- Prevent sleep until the charge limit is reached
- Scheduled charge limits, Top Up, calibration, pause, and discharge tasks
- Login launch and customizable menu-bar/dashboard display
- Follow-system language mode plus instant Chinese/English switching
- Optional Liquid Glass appearance that adapts to macOS 26/27 system materials
  and falls back to a compatible translucent effect on older macOS versions
- Unicode-safe live energy app names sourced from macOS application metadata
- Apple Shortcuts-compatible URL actions
- Opt-in issue recording with a copyable support ID
- One-click, locally generated diagnostic ZIP with privacy redaction
- Optional crash-report collection and opt-in energy-app names
- Bundled on-demand CLI with no additional resident process
- Standalone dashboard on app reopen when the menu bar icon is hidden

## Install

Drag `Aidente.app` to `/Applications`, open it, then enable charge management in
Settings → Charging. macOS may ask you to approve the background helper in
System Settings → General → Login Items.

The distributed local build is ad-hoc signed, not Apple-notarized. If Finder
blocks the first launch, right-click the app and choose Open.

## Shortcuts URLs

Use Shortcuts → Open URLs with one of:

```text
aidente://set-limit?value=80
aidente://top-up
aidente://calibrate
aidente://pause
aidente://discharge?value=70
aidente://resume
```

## Diagnostics and CLI

Open Settings → Diagnostics to start an issue-recording session or export a
diagnostic ZIP. The default package excludes energy-app names and intentionally
does not collect account names, serial numbers, or network configuration.

The optional CLI is bundled at:

```text
/Applications/Aidente.app/Contents/Resources/aidente
```

It can show status or trigger the same URL-based actions as the graphical app:

```text
aidente status
aidente limit 80
aidente pause
aidente resume
aidente dashboard
aidente diagnostics
```

## Build from source

The repository includes fixed copies of its open-source dependencies so it can
build without downloading packages:

```text
chmod +x BuildSupport/build_app.sh
BuildSupport/build_app.sh
```

The output is `Dist/Aidente.app`.

## Safety and uninstall

Before uninstalling, turn off Manage Charging in Settings → Charging. This
unregisters the privileged helper and restores the default charge, adapter, and
MagSafe LED states.

Low-level SMC controls are private interfaces and may change in future macOS
versions. Use at your own risk and keep a charger available during calibration.

## License and attribution

Aidente is licensed under GPL-3.0 because it is based on the GPL-3.0 Stasis
project. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

AlDente is a trademark of its respective owner. Aidente is independent and is
not affiliated with, endorsed by, or distributed by AppHouseKitchen.
