# Detergent Factory Management App

A Flutter application for detergent factory owners with Arabic RTL support. Runs on **Android**, **Windows**, **Linux**, and **macOS**.

## Features

- Production Management
- Multi-step form workflow
- Dynamic tables with add/remove functionality
- Automatic calculations
- Offline-first architecture
- PDF export capability
- Multi-platform support (Android, Windows, Linux, macOS)

## Prerequisites

- Flutter SDK (tested with 3.38.5 and Dart 3.10.4)
- For Android: Android Studio with Android SDK
- For Windows: Visual Studio with C++ development tools
- For Linux: CMake, GTK development libraries, pkg-config
- For macOS: Xcode

## Getting Started

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Check available devices:
```bash
flutter devices
```

## Running on Different Platforms

### Android
```bash
# Connect an Android device or start an emulator
flutter run
# Or specify Android explicitly
flutter run -d android
```

### Windows
```bash
flutter run -d windows
```

### Linux
```bash
flutter run -d linux
```

### macOS
```bash
flutter run -d macos
```

## Building for Release

### Android APK
```bash
flutter build apk --release
# Or for app bundle
flutter build appbundle --release
```

### Windows
```bash
flutter build windows --release
```

### Linux
```bash
flutter build linux --release
```

### macOS
```bash
flutter build macos --release
```

## Project Structure

- `lib/models/` - Data models
- `lib/providers/` - State management (Provider)
- `lib/screens/` - UI screens
- `lib/widgets/` - Reusable widgets
- `android/` - Android platform-specific code
- `windows/` - Windows platform-specific code
- `linux/` - Linux platform-specific code
- `macos/` - macOS platform-specific code

## Backups and saved drafts

Use the backup icon in the main menu to create a verified backup of warehouse,
shop stock, production costing and packaging costing. Leave the path blank to
save in the application documents directory under `ERP Backups`, or enter a new
writable file path. Existing filenames are not overwritten. Copy backup text to
transfer it manually, including from Android, and retain a copy outside the device.

To restore, provide a backup path or paste its backup text. The app validates it,
asks for confirmation, and saves the current data before replacing it. If saving
or restore fails, follow the retry message. Interrupted restores resume on startup.
Current unreadable data is preserved in a raw recovery file for manual repair.

Costing drafts save automatically and return after restart. A failed save displays
a retry banner. Backups contain plain JSON and replace the complete local dataset;
they are not a way to merge simultaneous changes from Android and Windows.

See [ERP_ASSESSMENT.md](ERP_ASSESSMENT.md) for implemented reliability work and
remaining business modules.

## Business documents

Open **Business documents** from the main menu to view production, purchase
receipts and sales history. Receive a purchase to add raw stock with supplier,
currency, price and payment details. Record a sale from this menu or a shop item;
the document preserves the customer, quantity, price and currency. Select currency
explicitly. USD and SYP amounts currently use two decimal places.

Production corrections retain the original batch, post a reversal, and create a
linked replacement. Cancelling a batch restores its ingredients and keeps the
history. Trade document reversals require a reason; a purchase return is blocked
if its stock has been consumed. Use the shop's history icon for sales records.
Backups include these documents, and destructive history resets are disabled.

These initial documents support one item each. Tax, later payments, financial
journals and automatic finished-goods transfers remain on the ERP roadmap.

## Platform-Specific Notes

- **Android**: Minimum SDK version is set automatically by Flutter
- **Windows**: Requires Windows 10 or later
- **Linux**: Requires GTK 3.0 or later
- **macOS**: Requires macOS 10.11 or later



Later payments: open Business documents, choose Purchases or Sales, then Record
payment on an active document. Enter the amount in its displayed currency and
an optional reference. History retains each allocation and updates the balance.
Backups include these payments. Reversal of documents with later payments is
blocked pending refund reconciliation.


Customers & suppliers: use the people icon on the main menu to create or edit
contact records. Choose a saved active record when entering a receipt or sale.
Posted documents retain their original party name. Inactive records remain in
history. Outstanding balances shown on records include only documents linked
to that record ID and are kept separate by currency. Existing manually named
documents remain available in Business documents.

## Current ERP baseline

The application now includes multi-line purchases/sales, payments/refunds, customers/suppliers, finished-goods transfers, production orders with versioned recipes and approval/quality release, lot/expiry checks, stock counts, per-currency journals/trial balance, period locks, local accounts/roles, bilingual PDFs and validated backups. Storage schema is v12 with older-state migration. Android and Windows retain the original Cairo/Arabic/English template with responsive layouts.

Read [ERP_ASSESSMENT.md](ERP_ASSESSMENT.md) for implemented scope and outstanding business features, and [RELEASE_GUIDE.md](RELEASE_GUIDE.md) before deployment. Windows packages can be created with scripts/package-windows.ps1. Signed Android release requires a confirmed application ID and private signing configuration; debug signing is never used for release. Devices currently operate independently without synchronization. Tax is deliberately unset until jurisdiction and company details are confirmed.


Version 1.0.4 adds Finance document/ledger reconciliation. Follow [BUSINESS_CYCLE_TEST.md](BUSINESS_CYCLE_TEST.md) to validate a complete sample purchase-to-cash cycle with expected quantities and balances. Windows sign-in in 1.0.3 was confirmed by the user; automatic regression coverage is now 55 passing tests.

Version 1.0.5 adds explicit packaging fill units, measured density for volume fills, legacy unit confirmation, costing readiness checks and a liquid/container/label breakdown. See [COSTING_GUIDE.md](COSTING_GUIDE.md). Packaging draft schema is v2; inventory schema remains v12. All 61 automated tests pass. These are cost estimates; automatic valuation/COGS and labor/overhead/waste posting remain pending.
