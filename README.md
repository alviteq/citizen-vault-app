# OwnKeep application

Keep What Matters. Own Your Data.

This Flutter package is the Android/iOS presentation and dependency-composition
root. Milestone 6 provides file, gallery, and camera import actions plus durable
processing cards. The application now creates a passphrase-protected vault,
stores only portable encrypted/public key metadata in app-private storage, and
composes the SQLCipher session, File Root Key, object store, and ingestion
coordinator after successful unlock. OwnKeep 1.3 authenticates an original
before opening it in the local PDF/image/text viewer and supports an explicitly
confirmed unencrypted Save a copy operation through the system document
provider. OwnKeep 1.4 adds the first real-data Life Dashboard and reframes
capture, processing, and review as a private Inbox. Run commands from the
repository root so the Dart pub workspace and pinned lockfile are used.

Android requires API 29 or newer. iOS remains scaffolded for architecture and
build compatibility; device security integration began in Milestone 1.

iOS camera/gallery purpose strings are declared. Android uses scoped system
pickers, recovers `image_picker` results if the activity is destroyed, blocks
screenshots, and excludes the private vault from Android cloud/device backup.
Portable `.cvault` export is the supported recovery path. No selected picker or
image-processing dependency performs network operations.

## Production validation

Before tagging a release, run from the repository root:

```bash
./scripts/format.sh
./scripts/analyze.sh
./scripts/test_all.sh
./scripts/build_android_debug.sh
```

Then run `flutter build ios --simulator` from this package and execute the
integration suite on attached Android and iOS devices. Release signing
credentials remain outside source control; `scripts/build_android_release.sh`
fails closed until signing is explicitly configured.
