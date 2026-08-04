#ifndef RUNNER_NATIVE_CHANNELS_H_
#define RUNNER_NATIVE_CHANNELS_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// Registers OwnKeep's Linux OCR, file, storage, and security bridges.
void register_native_channels(FlView* view, GtkWindow* window);

#endif  // RUNNER_NATIVE_CHANNELS_H_
