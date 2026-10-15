import '../../../l10n/app_localizations.dart';
import '../domain/entities/chat_message.dart';

/// Localised one-line description of a message (reply quotes, message info).
extension MessagePreview on ChatMessage {
  String preview(AppL10n l) => previewText(
    l.photo,
    voiceLabel: l.voiceMessage,
    videoLabel: l.video,
    fileLabel: l.document,
  );
}
