import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/image_processor.dart';

final imageProcessorProvider = Provider<ImageProcessor>(
  (_) => ImageProcessor(),
);

/// Uses the system photo picker / camera; no broad storage permission needed.
final imagePickerProvider = Provider<ImagePicker>((_) => ImagePicker());
