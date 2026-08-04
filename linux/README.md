# OwnKeep for Linux

OwnKeep uses the system GTK file chooser, Secret Service keyring, OpenSSL,
`statvfs`, and Tesseract OCR on Linux.

Ubuntu/Debian build and runtime dependencies:

```bash
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libssl-dev \
  tesseract-ocr tesseract-ocr-eng tesseract-ocr-hin tesseract-ocr-mar \
  tesseract-ocr-tam tesseract-ocr-tel tesseract-ocr-kan \
  tesseract-ocr-mal tesseract-ocr-ben
```

Build and run:

```bash
flutter config --enable-linux-desktop
flutter doctor
flutter build linux --debug
flutter run -d linux
```

The desktop key envelope is encrypted with AES-256-GCM. Its random wrapping
key is stored in the logged-in user's Secret Service keyring. Linux does not
provide one universal biometric API across desktop environments, so OwnKeep
does not claim biometric authentication on Linux.
