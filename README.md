<div align="center">

<img src="assets/images/baobi_logo.png" alt="Baobi logo" width="120" />

# Baobi Wristband Manager

**Hospital patient-wristband printing & management for the BB720A thermal printer**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-informational)]()
[![Firebase](https://img.shields.io/badge/cloud%20sync-Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![License](https://img.shields.io/badge/license-Proprietary-red)](#license)

If this project is useful to you, **⭐ star the repo** — it's the easiest way to keep tabs on updates, and it tells me what to build next.

</div>

---

## What this is

Baobi Wristband Manager is a desktop/mobile application that drives the **BB720A medical wristband printer**, letting hospital front-desk staff pull up a patient record and print an ID wristband (name, QR/barcode, admission details) in seconds. It's built to work as the software half of a package deal: **BB720A printer + wristband paper + this app**.

The app is designed around real hospital IT constraints — it talks directly to a hospital's existing **HIS (Hospital Information System)** over REST, works fully offline against a local database when the network or HIS is unreachable, and syncs print history to the cloud per-hospital when it's available.

## Features

- 🖨️ **BB720A-native printing** — landscape wristband layout tuned to the printer's paper geometry, with selectable paper stock configs and printer/channel settings.
- 🌏 **CJK font support** — embedded font fallback so Chinese patient names print correctly, not as blank boxes.
- 🏥 **HIS integration** — REST client tolerant of the inconsistencies real hospital systems have in practice: trailing slashes, nested JSON shapes, mixed auth schemes, and internal HTTPS endpoints with self-signed certificates.
- 📶 **Offline-first** — local SQLite storage for patients and print history, so the front desk keeps working when the hospital network or HIS is down.
- ☁️ **Multi-hospital cloud sync** — optional Firebase-backed sync, isolated per hospital via Firebase Auth + Firestore security rules (one hospital's data is never reachable from another's account).
- 📋 **Print queue & history** — track what's been printed, re-print, and review patient/print records.
- 🔒 **Admin lock** — PIN/password gate (hashed, never stored in plaintext) for settings that shouldn't be touched by front-desk staff.
- 🖥️ **Cross-platform Flutter app** — Windows is the primary target (with a bundled Inno Setup installer), plus macOS, Linux, Android, iOS, and Web builds from the same codebase.

## Tech stack

| Layer | Choice |
|---|---|
| UI / App framework | Flutter (Dart), Provider for state management |
| Local storage | SQLite (`sqflite` / `sqflite_common_ffi` on desktop) |
| Cloud sync | Firebase Auth + Cloud Firestore (REST, per-hospital tenant isolation) |
| Printing | `printing` + `pdf` packages, generating a print-ready PDF per wristband |
| HIS integration | `http`, configurable REST endpoints, optional self-signed TLS trust |
| Packaging | Inno Setup (Windows installer) |

## Getting started

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.11.5`, see [pubspec.yaml](pubspec.yaml)).

```bash
git clone https://github.com/abdullahwaseem-dev/baobi-wristband-manager.git
cd baobi-wristband-manager
flutter pub get
flutter run -d windows   # or: macos / linux / chrome / an attached device
```

Run the test suite:

```bash
flutter test
```

### Configuration

- **HIS connection** — set your hospital's REST endpoint and auth from the in-app settings dialog (`Settings → HIS`); it's stored locally, not hardcoded.
- **Cloud sync (optional)** — each hospital signs in with its own Firebase account; data is partitioned per-hospital by Firestore security rules (see [firestore.rules](firestore.rules)). No shared credentials are checked into this repo.
- **Printer** — select your Windows printer name and paper stock (`BB720A` configs) from `Settings → Printer`.

## Project structure

```
lib/
├── core/        # theming, localized strings
├── models/      # Patient, HisConfig, PaperConfig, PrintRecord
├── services/    # DB, printing, HIS client, Firebase sync, settings
├── state/       # app-wide state (Provider)
├── screens/     # Home, Print, Patient List, Print Queue
└── widgets/     # shared UI + dialogs
test/            # unit/integration tests (HIS, sync, printing, DB)
tool/            # dev scripts (mock HIS server, icon/user-guide generation)
docs/            # user guide
installer/       # Windows Inno Setup script
```

## Get the full package

This repository covers the **software**. If you're a hospital or distributor and want the complete solution — **BB720A printers, compatible wristband paper stock, and this software preconfigured for your HIS** — reach out:

📧 **maw112266@gmail.com**

## License

This source is shared publicly for demonstration and portfolio purposes. All rights reserved — see [LICENSE](LICENSE) for terms. For commercial licensing or deployment, contact the email above.

---

<div align="center">

Built and maintained by [@abdullahwaseem-dev](https://github.com/abdullahwaseem-dev).
**Star ⭐ and follow the repo** to get notified about new releases and features.

</div>
