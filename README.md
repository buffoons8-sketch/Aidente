# Aidente

Aidente is an independent, open-source macOS menu bar app for Apple Silicon
MacBooks. It monitors battery and power data and can manage low-level charging
controls through an explicitly approved privileged helper.

Version 6.0.1 adds secure background updates from the official GitHub Releases
page. Aidente checks stable releases after launch and every six hours, verifies
the GitHub SHA-256 digest, app signature, bundle identity, version, and arm64
architecture, then replaces the installed app through a rollback-capable helper.

This project does not contain AlDente Pro code, assets, activation logic, or
modified binaries. It implements similar battery-care workflows from public
behavior descriptions and GPL-compatible open-source foundations.

## Version 6.0.2 (Build 20)

- Narrow vertical menu-bar battery with bottom-up fill. Icon-only menu width
  decreases from 33 to 19 points, or from 37 to 25 points with the percentage
  inside. Combined battery/power mode sizes the item to the actual wattage text.
- Charging and adapter control are one serialized, verified transaction. Holding
  a charge limit requests that the adapter remain connected; firmware may still
  draw battery power above the ceiling. Normal mode resumes 2 percentage
  points below the limit; sailing mode retains its configured range.
- Automatic discharge defaults to off. Explicitly saved preferences are preserved.
  When enabled, it starts on power connection or a limit change only if more than
  1 point above the limit, and does not restart for normal charging overshoot.
- The privileged helper acknowledges system sleep after applying/readback of the
  sleep policy, including when unplugged before sleep. Wake keeps the hold until
  the app sends a fresh policy. A low-frequency watchdog repairs register drift
  while the daemon is able to run; it does not poll during deep sleep.
- Charging control uses an explicitly authorized local LaunchDaemon with pinned
  client/helper identities. Updated app/helper binaries require renewed
  administrator authorization. Background polling never prompts for a password.
  Wake re-probes hardware capabilities and XPC failures no longer leave capability
  loading hung.
- Capability-based selection of old `CH0B/CH0C`, `CHTE`, and new firmware-managed
  `bfF0/bfD0/bfE0` controls (not selection by macOS version number). The firmware
  interval is applied proactively while charging. A hold uses the configured
  ceiling or captures the current raw capacity if it is lower, without chasing
  subsequent drops. New firmware may run from battery above that ceiling;
  adapter-only power is not guaranteed. The original interval is saved and
  restored when management is disabled. Failed writes are read back and rolled
  back rather than reported as success.
- Diagnostics include requested/applied adapter and charging state, plus power
  event and hardware-key logs.

Firmware-specific sleep persistence
must still be checked on affected machines; this is not a blanket compatibility
claim for all macOS 26/27 firmware.

Newer firmware shipped with macOS 15.8/26.7 and macOS 27 betas may remove or
restrict charging registers. Aidente reports the unsupported control instead of
silently substituting adapter disconnection (which would cycle the battery).
Re-registering the helper cannot grant Apple's private firmware entitlements.

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
- Automatic and manual update checks against official stable GitHub Releases
- One-click background download, verification, installation, and relaunch
- Rollback to the previous app when replacement or relaunch fails

## Install

Users upgrading from 6.0 must install 6.0.1 manually once because 6.0 did not
yet contain the updater. Updates after 6.0.1 can be completed inside Aidente.

Drag `Aidente.app` to `/Applications`, open it, then enable charge management in
Settings → Charging, then authorize the administrator installation. After updating
to 6.0.2, click Repair Control Service to authorize the new app/helper identity.
See [administrator installation notes](administrator-install-notes.md).

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

Run `zsh BuildSupport/test_charging.sh` after building for hardware-free charging
policy and ordered-write regression tests. Render the production icon at 3x with
`Dist/Aidente.app/Contents/MacOS/Aidente --render-status-icons=/tmp/Aidente-icons.png`.

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
