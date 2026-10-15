import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../attachments/presentation/viewmodels/attachment_providers.dart';
import '../../data/plugin_media_picker.dart';
import '../../data/plugin_media_previews.dart';
import '../../domain/media_previews.dart';
import '../../data/file_opener.dart';
import '../../domain/media_picker.dart';

final mediaPreviewsProvider = Provider<MediaPreviews>(
  (_) => PluginMediaPreviews(),
);

final mediaPickerProvider = Provider<MediaPicker>(
  (ref) => PluginMediaPicker(
    ref.watch(imagePickerProvider),
    ref.watch(mediaPreviewsProvider),
  ),
);

final fileOpenerProvider = Provider<FileOpener>((_) => SystemFileOpener());
