import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/failure.dart';

/// Downloads a document into a temp folder under its real name, then hands it
/// to the system share sheet ("Open in…" / "Save to Files" / other apps).
abstract interface class FileOpener {
  Future<void> open({
    required String url,
    required String messageId,
    required String fileName,
    required String mimeType,
  });
}

class SystemFileOpener implements FileOpener {
  @override
  Future<void> open({
    required String url,
    required String messageId,
    required String fileName,
    required String mimeType,
  }) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'downloads', messageId));
    await dir.create(recursive: true);
    // The message id is a UUID and the name is sanitised, so this stays inside dir.
    final file = File(p.join(dir.path, p.basename(fileName)));
    if (!await file.exists() || await file.length() == 0) {
      final client =
          HttpClient()..connectionTimeout = const Duration(seconds: 20);
      try {
        final req = await client.getUrl(Uri.parse(url));
        final res = await req.close();
        if (res.statusCode != 200) {
          await res.drain<void>();
          throw const NetworkFailure();
        }
        final sink = file.openWrite();
        await res.pipe(sink);
      } catch (e) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        throw Failure.from(e);
      } finally {
        client.close();
      }
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: fileName)],
      ),
    );
  }
}
