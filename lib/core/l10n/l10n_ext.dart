import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../errors/failure.dart';

export '../../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}

/// Human-readable, localized copy for a [Failure]. Never exposes raw
/// Firebase exception text.
String failureMessage(AppL10n l, Failure f) => switch (f) {
  AuthFailure(:final reason) => switch (reason) {
    AuthReason.invalidCredentials => l.errInvalidCredentials,
    AuthReason.emailInUse => l.errEmailInUse,
    AuthReason.weakPassword => l.errWeakPassword,
    AuthReason.invalidEmail => l.errInvalidEmail,
    AuthReason.userDisabled => l.errUserDisabled,
    AuthReason.tooManyRequests => l.errTooManyRequests,
    AuthReason.accountExists => l.errAccountExists,
    AuthReason.cancelled => l.errSignInCancelled,
    AuthReason.reauthRequired => l.errReauthRequired,
    AuthReason.emailNotVerified => l.errEmailNotVerified,
    AuthReason.other => l.errGeneric,
  },
  NetworkFailure() => l.errNetwork,
  PermissionFailure() => l.errPermission,
  ValidationFailure(:final reason) => switch (reason) {
    ValidationReason.usernameInvalid => l.errUsernameInvalid,
    ValidationReason.usernameTaken => l.errUsernameTaken,
    ValidationReason.displayNameInvalid => l.errDisplayNameInvalid,
    ValidationReason.messageEmpty => l.errMessageEmpty,
    ValidationReason.messageTooLong => l.errMessageTooLong,
    ValidationReason.fileTooLarge => l.errFileTooLarge,
    ValidationReason.fileUnsupported => l.errFileUnsupported,
    ValidationReason.selfConversation => l.errSelfConversation,
    ValidationReason.other => l.errGeneric,
  },
  UploadFailure(:final reason) => switch (reason) {
    UploadReason.tooLarge => l.errFileTooLarge,
    UploadReason.unsupported => l.errFileUnsupported,
    UploadReason.cancelled => l.errUploadCancelled,
    UploadReason.storage => l.errUploadFailed,
  },
  UnknownFailure(:final diagnosticId) => l.errUnknown(diagnosticId),
};
