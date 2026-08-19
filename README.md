# Medication Tracker

An open source, local-first iPhone app for medicines, vitamins and supplements. Add scheduled or as-needed medicines, group them into treatment plans, receive local reminders, record doses, track refills, and keep a completion history.

There is no account, backend, analytics SDK, or network requirement. Data is stored on the device with SwiftData.

## Requirements

- macOS with Xcode 16 or later
- An iOS 17 or later simulator or iPhone

The checked-in Xcode project has one iOS app target, one unit-test target, and one UI-test target. XcodeGen is only needed when changing `project.yml`.

## Run the app

1. Clone the repository.
2. Open `MedicationTracker.xcodeproj` in Xcode.
3. Select the `MedicationTracker` scheme and an iPhone simulator.
4. Press **Run** (`⌘R`).

The app opens on an empty Medications Catalog. Use `+` to add a medicine or treatment plan. Notification permission is requested only when reminders are turned on.

## Features

- Four-tab interface: History, Today, Medications, and Settings
- Scheduled and as-needed medication setup
- Daily and every-other-day presets, linked 8-hour/12-hour times, and custom times
- Finite or ongoing durations
- Treatment plans with optional prescriber
- Take, skip, snooze, take-late, and as-needed dose logging
- Local notification actions for Take, Skip, and Snooze
- Optional notes, daily cap, quantity remaining, and refill threshold
- Completion history and medication restart
- Optional Face ID/device-passcode app lock
- Dynamic Type, VoiceOver labels, and 44-point minimum controls

Dose times are stored as wall-clock times. Existing times are not converted when the phone’s time zone changes.

## Tests

From the repository root:

```sh
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
xcodebuild test \
  -project MedicationTracker.xcodeproj \
  -scheme MedicationTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The test suite covers schedule/duration calculations, daily caps, inventory/refill behaviour, and an end-to-end UI flow that creates a medicine and groups it into a treatment plan.

If you edit `project.yml`, regenerate the project first with:

```sh
xcodegen generate
```

## Safety

Medication Tracker is a personal log only. It is not medical advice and is not a substitute for a pharmacist or a doctor.

The complete product specification is in [issue #1](https://github.com/jusso-dev/medication-tracker/issues/1).

## Licence

MIT. See [LICENSE](LICENSE).
