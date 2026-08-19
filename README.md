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
- Offline Australian medicine-name lookup with common brand names
- On-device OCR for medicine labels and prescriptions, with camera and photo input
- Daily and every-other-day presets, linked 8-hour/12-hour times, and custom times
- One-tap all-days selection, clear-dose input, and guided schedule validation
- Finite or ongoing durations
- Treatment plans with optional prescriber
- Take, skip, snooze, take-late, and as-needed dose logging
- Local notification actions for Take, Skip, and Snooze
- Optional notes, package expiry, daily cap, quantity remaining, and refill threshold
- Refill-script review with explicit expiry, authorised/remaining repeats, and refill recording
- One-time, privacy-controlled care snapshots shared through the iOS share sheet
- Completion history and medication restart
- Optional Face ID/device-passcode app lock
- Dynamic Type, VoiceOver labels, and 44-point minimum controls

Dose times are stored as wall-clock times. Existing times are not converted when the phone’s time zone changes.

OCR results and refill-script status must be reviewed against the original label or prescription. Script status is a personal record based on the entered expiry and repeat count; a pharmacist determines whether it can be dispensed. Simulator builds use the photo picker because document-camera capture requires a physical camera.

Care Share always exports active medicine names, strengths, schedules, treatment dates, daily caps, package expiry, and treatment-plan titles. Notes, quantities, refill-script records, and prescriber names are optional and off by default. Dose history is excluded and imported reminders default to off. Use the system share sheet to select AirDrop; AirDrop encrypts transport, while the snapshot file remains readable by anyone who receives it. Other destinations use their own security. On supported iPhones, iOS can start proximity AirDrop when the top edges are held together. Apps cannot replace or silently trigger Apple’s NameDrop/AirDrop gesture or animation.

## Tests

From the repository root:

```sh
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
xcodebuild test \
  -project MedicationTracker.xcodeproj \
  -scheme MedicationTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The test suite covers schedule/duration calculations, OCR parsing, Australian brand lookup, refill-script status and persistence, daily caps, inventory/refill behaviour, Settings scrolling, and end-to-end medicine and treatment-plan flows.

If you edit `project.yml`, regenerate the project first with:

```sh
xcodegen generate
```

## Safety

Medication Tracker is a personal log only. It is not medical advice and is not a substitute for a pharmacist or a doctor.

The complete product specification is in [issue #1](https://github.com/jusso-dev/medication-tracker/issues/1).

## Licence

MIT. See [LICENSE](LICENSE).
