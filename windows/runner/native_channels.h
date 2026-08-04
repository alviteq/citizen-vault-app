#ifndef RUNNER_NATIVE_CHANNELS_H_
#define RUNNER_NATIVE_CHANNELS_H_

#include <flutter/flutter_engine.h>
#include <windows.h>

// Registers OwnKeep's OCR, export, and storage-capacity platform channels.
void RegisterNativeChannels(flutter::FlutterEngine* engine, HWND window);

#endif  // RUNNER_NATIVE_CHANNELS_H_
