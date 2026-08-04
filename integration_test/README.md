# Integration tests

Device integration tests cover native entropy and Milestone 5 cross-platform
restore. The portability test restores the committed fixture, provisions a new
Android Keystore or iOS Keychain envelope, and generates a fixture in the app
cache for the opposite platform to consume.

Run all Android integration tests with an attached device:

```bash
ANDROID_DEVICE_ID=<flutter-device-id> ./scripts/run_integration_android.sh
```

Capture and commit an Android-origin fixture with:

```bash
ANDROID_DEVICE_ID=<flutter-device-id> \
  ./scripts/capture_android_interop_fixture.sh
```

The capture command must be run on physical Android hardware before the Android
provenance acceptance gate is claimed.
