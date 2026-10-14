import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Hushlo'**
  String get appName;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Messages will send when you reconnect.'**
  String get offlineBanner;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @react.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get react;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @muted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get muted;

  /// No description provided for @introHeadline.
  ///
  /// In en, this message translates to:
  /// **'Good conversations, less noise.'**
  String get introHeadline;

  /// No description provided for @introBody.
  ///
  /// In en, this message translates to:
  /// **'A calm, private place to talk with the people you already know. No feed, no strangers.'**
  String get introBody;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get haveAccount;

  /// No description provided for @needAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get needAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that email, a reset link is on its way.'**
  String get resetEmailSent;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}. Open it, then come back here.'**
  String verifyEmailBody(String email);

  /// No description provided for @iVerified.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified my email'**
  String get iVerified;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @verificationSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent.'**
  String get verificationSent;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get setupTitle;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose profile photo'**
  String get chooseAvatar;

  /// No description provided for @avatarOptional.
  ///
  /// In en, this message translates to:
  /// **'Photo (optional)'**
  String get avatarOptional;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @bioOptional.
  ///
  /// In en, this message translates to:
  /// **'Short bio (optional)'**
  String get bioOptional;

  /// No description provided for @usernameHelp.
  ///
  /// In en, this message translates to:
  /// **'3–20 letters, numbers or underscores. Others find you by this exact name.'**
  String get usernameHelp;

  /// No description provided for @usernameAvailable.
  ///
  /// In en, this message translates to:
  /// **'Username is available'**
  String get usernameAvailable;

  /// No description provided for @usernameChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get usernameChecking;

  /// No description provided for @usernameCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check right now. We\'ll verify when you continue.'**
  String get usernameCheckFailed;

  /// No description provided for @usernameLocked.
  ///
  /// In en, this message translates to:
  /// **'Usernames can\'t be changed in this version.'**
  String get usernameLocked;

  /// No description provided for @primerTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get primerTitle;

  /// No description provided for @primerDiscover.
  ///
  /// In en, this message translates to:
  /// **'People can find you only by your exact username. There is no public directory.'**
  String get primerDiscover;

  /// No description provided for @primerStorage.
  ///
  /// In en, this message translates to:
  /// **'Messages and photos are stored in the cloud so they sync and keep history.'**
  String get primerStorage;

  /// No description provided for @primerNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications are optional and you control whether they show message text.'**
  String get primerNotifications;

  /// No description provided for @primerNotE2ee.
  ///
  /// In en, this message translates to:
  /// **'Messages are protected in transit and by access rules, but they are not end-to-end encrypted.'**
  String get primerNotE2ee;

  /// No description provided for @chatsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatsEmptyTitle;

  /// No description provided for @chatsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Find a friend by their username and say hello.'**
  String get chatsEmptyBody;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get startConversation;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @searchChats.
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get searchChats;

  /// No description provided for @archivedChats.
  ///
  /// In en, this message translates to:
  /// **'Archived chats'**
  String get archivedChats;

  /// No description provided for @archivedCount.
  ///
  /// In en, this message translates to:
  /// **'Archived ({count})'**
  String archivedCount(int count);

  /// No description provided for @noArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived chats.'**
  String get noArchived;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No matching conversations.'**
  String get noResults;

  /// No description provided for @notifPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Get notified when someone messages you.'**
  String get notifPromptBody;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @deletedAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleted account'**
  String get deletedAccount;

  /// No description provided for @exactUsername.
  ///
  /// In en, this message translates to:
  /// **'Exact username'**
  String get exactUsername;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter someone\'s exact username to start a chat.'**
  String get searchHint;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'No one found with that username.'**
  String get userNotFound;

  /// No description provided for @inviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get inviteFriend;

  /// No description provided for @inviteText.
  ///
  /// In en, this message translates to:
  /// **'Let\'s chat on Hushlo! My username is @{username}.'**
  String inviteText(String username);

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @attachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Attach photo'**
  String get attachPhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get takePhoto;

  /// No description provided for @cancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get cancelReply;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @newMessages.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get newMessages;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Say hello'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'This is the start of your conversation with {name}.'**
  String chatEmptyBody(String name);

  /// No description provided for @originalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Original message unavailable'**
  String get originalUnavailable;

  /// No description provided for @statusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get statusSending;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send.'**
  String get sendFailed;

  /// No description provided for @sendRejected.
  ///
  /// In en, this message translates to:
  /// **'This message was rejected. You may not be able to message this person.'**
  String get sendRejected;

  /// No description provided for @youBlocked.
  ///
  /// In en, this message translates to:
  /// **'You blocked this account.'**
  String get youBlocked;

  /// No description provided for @accountDeletedNotice.
  ///
  /// In en, this message translates to:
  /// **'This account was deleted. You can\'t send new messages.'**
  String get accountDeletedNotice;

  /// No description provided for @blockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockTitle(String name);

  /// No description provided for @blockBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to message you, and you won\'t be able to message them. You can unblock later in Settings.'**
  String get blockBody;

  /// No description provided for @photoPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Hushlo doesn\'t have permission to use the camera or photos.'**
  String get photoPermissionDenied;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @sendPhoto.
  ///
  /// In en, this message translates to:
  /// **'Send photo'**
  String get sendPhoto;

  /// No description provided for @captionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption'**
  String get captionHint;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get uploading;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTitle;

  /// No description provided for @reportBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us what\'s wrong. Reports are reviewed by our team and are never shown to the other person.'**
  String get reportBody;

  /// No description provided for @reportDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details (optional)'**
  String get reportDetails;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Your report was sent.'**
  String get reportSent;

  /// No description provided for @reasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reasonSpam;

  /// No description provided for @reasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get reasonHarassment;

  /// No description provided for @reasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reasonInappropriate;

  /// No description provided for @reasonImpersonation.
  ///
  /// In en, this message translates to:
  /// **'Impersonation'**
  String get reasonImpersonation;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reasonOther;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsOn.
  ///
  /// In en, this message translates to:
  /// **'Message notifications'**
  String get notificationsOn;

  /// No description provided for @notifDeniedHelp.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked in system settings.'**
  String get notifDeniedHelp;

  /// No description provided for @showPreviews.
  ///
  /// In en, this message translates to:
  /// **'Show message previews'**
  String get showPreviews;

  /// No description provided for @showPreviewsHelp.
  ///
  /// In en, this message translates to:
  /// **'Off by default. When off, notifications just say \"New message\".'**
  String get showPreviewsHelp;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @privacyAndSafety.
  ///
  /// In en, this message translates to:
  /// **'Privacy & safety'**
  String get privacyAndSafety;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// No description provided for @noBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedTitle;

  /// No description provided for @noBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'People you block will appear here.'**
  String get noBlockedBody;

  /// No description provided for @clearImageCache.
  ///
  /// In en, this message translates to:
  /// **'Clear image cache'**
  String get clearImageCache;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Image cache cleared.'**
  String get cacheCleared;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get terms;

  /// No description provided for @communityGuidelines.
  ///
  /// In en, this message translates to:
  /// **'Community guidelines'**
  String get communityGuidelines;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @mute1h.
  ///
  /// In en, this message translates to:
  /// **'Mute for 1 hour'**
  String get mute1h;

  /// No description provided for @mute8h.
  ///
  /// In en, this message translates to:
  /// **'Mute for 8 hours'**
  String get mute8h;

  /// No description provided for @mute1w.
  ///
  /// In en, this message translates to:
  /// **'Mute for 1 week'**
  String get mute1w;

  /// No description provided for @muteForever.
  ///
  /// In en, this message translates to:
  /// **'Mute until I unmute'**
  String get muteForever;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What happens when you delete your account'**
  String get deleteWhatTitle;

  /// No description provided for @deleteWhat1.
  ///
  /// In en, this message translates to:
  /// **'Your profile, username and settings are permanently deleted.'**
  String get deleteWhat1;

  /// No description provided for @deleteWhat2.
  ///
  /// In en, this message translates to:
  /// **'Photos you uploaded and your notification tokens are deleted.'**
  String get deleteWhat2;

  /// No description provided for @deleteWhat3.
  ///
  /// In en, this message translates to:
  /// **'Messages you sent are deleted from your conversations.'**
  String get deleteWhat3;

  /// No description provided for @deleteWhat4.
  ///
  /// In en, this message translates to:
  /// **'The other person keeps their own messages; your name is replaced with \"Deleted account\".'**
  String get deleteWhat4;

  /// No description provided for @deleteIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get deleteIrreversible;

  /// No description provided for @deleteConfirmCheck.
  ///
  /// In en, this message translates to:
  /// **'I understand and want to delete my account'**
  String get deleteConfirmCheck;

  /// No description provided for @reauthExplain.
  ///
  /// In en, this message translates to:
  /// **'For your security, please confirm it\'s you before we delete your account.'**
  String get reauthExplain;

  /// No description provided for @confirmAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm and delete'**
  String get confirmAndDelete;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'That email or password isn\'t right.'**
  String get errInvalidCredentials;

  /// No description provided for @errEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account with that email already exists.'**
  String get errEmailInUse;

  /// No description provided for @errWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Use a password with at least 8 characters.'**
  String get errWeakPassword;

  /// No description provided for @errInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get errInvalidEmail;

  /// No description provided for @errUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get errUserDisabled;

  /// No description provided for @errTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get errTooManyRequests;

  /// No description provided for @errAccountExists.
  ///
  /// In en, this message translates to:
  /// **'This email already uses a different sign-in method. Sign in with that method first.'**
  String get errAccountExists;

  /// No description provided for @errSignInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled.'**
  String get errSignInCancelled;

  /// No description provided for @errReauthRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get errReauthRequired;

  /// No description provided for @errEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email first.'**
  String get errEmailNotVerified;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get errNetwork;

  /// No description provided for @errPermission.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get errPermission;

  /// No description provided for @errUsernameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 3–20 letters, numbers or underscores.'**
  String get errUsernameInvalid;

  /// No description provided for @errUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is taken.'**
  String get errUsernameTaken;

  /// No description provided for @errDisplayNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name (up to 50 characters).'**
  String get errDisplayNameInvalid;

  /// No description provided for @errMessageEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write a message first.'**
  String get errMessageEmpty;

  /// No description provided for @errMessageTooLong.
  ///
  /// In en, this message translates to:
  /// **'That message is too long.'**
  String get errMessageTooLong;

  /// No description provided for @errFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is too large (max 10 MB).'**
  String get errFileTooLarge;

  /// No description provided for @errFileUnsupported.
  ///
  /// In en, this message translates to:
  /// **'That file type isn\'t supported. Use JPG, PNG, WebP or HEIC.'**
  String get errFileUnsupported;

  /// No description provided for @errSelfConversation.
  ///
  /// In en, this message translates to:
  /// **'You can\'t start a chat with yourself.'**
  String get errSelfConversation;

  /// No description provided for @errUploadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Upload cancelled.'**
  String get errUploadCancelled;

  /// No description provided for @errUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get errUploadFailed;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected happened. Reference: {id}'**
  String errUnknown(String id);

  /// No description provided for @noPreview.
  ///
  /// In en, this message translates to:
  /// **'Tap to open the chat'**
  String get noPreview;

  /// No description provided for @readReceipts.
  ///
  /// In en, this message translates to:
  /// **'Read receipts'**
  String get readReceipts;

  /// No description provided for @readReceiptsHelp.
  ///
  /// In en, this message translates to:
  /// **'If you turn this off, you won\'t send or see read receipts. Delivery ticks still work.'**
  String get readReceiptsHelp;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get statusRead;

  /// No description provided for @tapForInfo.
  ///
  /// In en, this message translates to:
  /// **'Tap here for contact info'**
  String get tapForInfo;

  /// No description provided for @chatPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Messages are stored in the cloud and protected by access rules. They are not end-to-end encrypted.'**
  String get chatPrivacyNote;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact info'**
  String get contactInfo;

  /// No description provided for @sharedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Shared photos'**
  String get sharedPhotos;

  /// No description provided for @noSharedPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos shared yet.'**
  String get noSharedPhotos;

  /// No description provided for @bioEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bio yet.'**
  String get bioEmpty;

  /// No description provided for @viewPhoto.
  ///
  /// In en, this message translates to:
  /// **'View photo'**
  String get viewPhoto;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get filterUnread;

  /// No description provided for @filterPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get filterPinned;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @photoPreview.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoPreview;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account, privacy and appearance'**
  String get settingsSubtitle;

  /// No description provided for @featurePrivate.
  ///
  /// In en, this message translates to:
  /// **'Find people only by their exact username'**
  String get featurePrivate;

  /// No description provided for @featureCalm.
  ///
  /// In en, this message translates to:
  /// **'Calm notifications you control'**
  String get featureCalm;

  /// No description provided for @featureNoFeed.
  ///
  /// In en, this message translates to:
  /// **'No feed. No strangers. Just your circle.'**
  String get featureNoFeed;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Chat with your circle'**
  String get welcomeTagline;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get online;

  /// No description provided for @lastSeenToday.
  ///
  /// In en, this message translates to:
  /// **'last seen today at {time}'**
  String lastSeenToday(String time);

  /// No description provided for @lastSeenYesterday.
  ///
  /// In en, this message translates to:
  /// **'last seen yesterday at {time}'**
  String lastSeenYesterday(String time);

  /// No description provided for @lastSeenOn.
  ///
  /// In en, this message translates to:
  /// **'last seen {date}'**
  String lastSeenOn(String date);

  /// No description provided for @showLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen & online'**
  String get showLastSeen;

  /// No description provided for @showLastSeenHelp.
  ///
  /// In en, this message translates to:
  /// **'If you turn this off, others can\'t see when you were last online or when you\'re typing, and you can\'t see theirs.'**
  String get showLastSeenHelp;

  /// No description provided for @messageDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted'**
  String get messageDeleted;

  /// No description provided for @youDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'You deleted this message'**
  String get youDeletedMessage;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @deleteMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete message?} other{Delete {count} messages?}}'**
  String deleteMessagesTitle(int count);

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryone;

  /// No description provided for @deleteForMeOnly.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMeOnly;

  /// No description provided for @deleteForEveryoneHelp.
  ///
  /// In en, this message translates to:
  /// **'Removes the content for everyone in this chat. Only possible within 48 hours.'**
  String get deleteForEveryoneHelp;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your messages stay safe in your account. You\'ll need to sign in again to read them.'**
  String get signOutBody;

  /// No description provided for @deleteReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you leaving?'**
  String get deleteReasonTitle;

  /// No description provided for @deleteReasonHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. This is anonymous and helps us improve.'**
  String get deleteReasonHelp;

  /// No description provided for @reasonAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'I have another account'**
  String get reasonAnotherAccount;

  /// No description provided for @reasonPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy concerns'**
  String get reasonPrivacy;

  /// No description provided for @reasonNotUsing.
  ///
  /// In en, this message translates to:
  /// **'I\'m not using Hushlo'**
  String get reasonNotUsing;

  /// No description provided for @reasonNotifications.
  ///
  /// In en, this message translates to:
  /// **'Too many notifications'**
  String get reasonNotifications;

  /// No description provided for @reasonBetterApp.
  ///
  /// In en, this message translates to:
  /// **'I found a better app'**
  String get reasonBetterApp;

  /// No description provided for @reasonOtherLeave.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reasonOtherLeave;

  /// No description provided for @deleteReasonDetails.
  ///
  /// In en, this message translates to:
  /// **'Tell us more (optional)'**
  String get deleteReasonDetails;

  /// No description provided for @copyMessages.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyMessages;

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelSelection;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String blockUser(String name);

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZone;

  /// No description provided for @goToOriginal.
  ///
  /// In en, this message translates to:
  /// **'Go to original message'**
  String get goToOriginal;

  /// No description provided for @removeReaction.
  ///
  /// In en, this message translates to:
  /// **'Remove reaction'**
  String get removeReaction;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get typing;

  /// No description provided for @clearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get clearChat;

  /// No description provided for @clearChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this chat?'**
  String get clearChatTitle;

  /// No description provided for @clearChatBody.
  ///
  /// In en, this message translates to:
  /// **'All messages will be removed from your view. {name} keeps their copy.'**
  String clearChatBody(String name);

  /// No description provided for @clearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAction;

  /// No description provided for @chatCleared.
  ///
  /// In en, this message translates to:
  /// **'Chat cleared'**
  String get chatCleared;

  /// No description provided for @startSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Start something new'**
  String get startSheetTitle;

  /// No description provided for @newChatDesc.
  ///
  /// In en, this message translates to:
  /// **'Message someone by their username'**
  String get newChatDesc;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @newGroupDesc.
  ///
  /// In en, this message translates to:
  /// **'Chat with up to {max} people'**
  String newGroupDesc(int max);

  /// No description provided for @joinWithCode.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get joinWithCode;

  /// No description provided for @joinWithCodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Use an invite code from a group admin'**
  String get joinWithCodeDesc;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String membersCount(int count);

  /// No description provided for @addMembers.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get addMembers;

  /// No description provided for @selectMembers.
  ///
  /// In en, this message translates to:
  /// **'Select members'**
  String get selectMembers;

  /// No description provided for @membersSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} selected'**
  String membersSelected(int count, int max);

  /// No description provided for @searchYourChats.
  ///
  /// In en, this message translates to:
  /// **'Search your chats'**
  String get searchYourChats;

  /// No description provided for @addByUsername.
  ///
  /// In en, this message translates to:
  /// **'Add by username'**
  String get addByUsername;

  /// No description provided for @noContactsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet. Add people by their exact username below.'**
  String get noContactsYet;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name your group'**
  String get groupNameHint;

  /// No description provided for @groupPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Group photo (optional)'**
  String get groupPhotoOptional;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @groupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get groupInfo;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @youLower.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get youLower;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get makeAdmin;

  /// No description provided for @removeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove as admin'**
  String get removeAdmin;

  /// No description provided for @removeFromGroup.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get removeFromGroup;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @leaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this group?'**
  String get leaveGroupTitle;

  /// No description provided for @leaveGroupBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t get new messages from {name}. To come back, an admin has to approve you again.'**
  String leaveGroupBody(String name);

  /// No description provided for @removeMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeMemberTitle(String name);

  /// No description provided for @removeMemberBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t see new messages in this group.'**
  String get removeMemberBody;

  /// No description provided for @editGroupName.
  ///
  /// In en, this message translates to:
  /// **'Edit group name'**
  String get editGroupName;

  /// No description provided for @groupFull.
  ///
  /// In en, this message translates to:
  /// **'This group is full (up to {max} people).'**
  String groupFull(int max);

  /// No description provided for @cannotRemoveLastAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make someone else an admin first.'**
  String get cannotRemoveLastAdmin;

  /// No description provided for @memberLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Groups can have up to {max} people.'**
  String memberLimitReached(int max);

  /// No description provided for @onlyAdminsCan.
  ///
  /// In en, this message translates to:
  /// **'Only admins can do this.'**
  String get onlyAdminsCan;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @inviteCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Share this code. People who use it can ask to join; an admin approves them.'**
  String get inviteCodeHelp;

  /// No description provided for @createInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Create invite code'**
  String get createInviteCode;

  /// No description provided for @resetInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Create a new code'**
  String get resetInviteCode;

  /// No description provided for @turnOffInvite.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get turnOffInvite;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @shareCode.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareCode;

  /// No description provided for @inviteShareText.
  ///
  /// In en, this message translates to:
  /// **'Join \"{name}\" on Hushlo. Use this invite code: {code}'**
  String inviteShareText(String name, String code);

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @noActiveInvite.
  ///
  /// In en, this message translates to:
  /// **'No active invite code.'**
  String get noActiveInvite;

  /// No description provided for @joinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join requests'**
  String get joinRequests;

  /// No description provided for @noJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests.'**
  String get noJoinRequests;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @requestsPending.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String requestsPending(int count);

  /// No description provided for @joinGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a group'**
  String get joinGroupTitle;

  /// No description provided for @enterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get enterInviteCode;

  /// No description provided for @pasteCode.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get pasteCode;

  /// No description provided for @findGroup.
  ///
  /// In en, this message translates to:
  /// **'Find group'**
  String get findGroup;

  /// No description provided for @invalidInviteCode.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t valid or has been turned off.'**
  String get invalidInviteCode;

  /// No description provided for @requestToJoin.
  ///
  /// In en, this message translates to:
  /// **'Request to join'**
  String get requestToJoin;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. An admin needs to approve it.'**
  String get requestSent;

  /// No description provided for @alreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You\'re already in this group.'**
  String get alreadyMember;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelRequest;

  /// No description provided for @joinGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask a group admin for an invite code, then enter it here.'**
  String get joinGroupHelp;

  /// No description provided for @sysAdded.
  ///
  /// In en, this message translates to:
  /// **'{actor} added {target}'**
  String sysAdded(String actor, String target);

  /// No description provided for @sysRemoved.
  ///
  /// In en, this message translates to:
  /// **'{actor} removed {target}'**
  String sysRemoved(String actor, String target);

  /// No description provided for @sysLeft.
  ///
  /// In en, this message translates to:
  /// **'{actor} left'**
  String sysLeft(String actor);

  /// No description provided for @sysRenamed.
  ///
  /// In en, this message translates to:
  /// **'{actor} changed the group name'**
  String sysRenamed(String actor);

  /// No description provided for @groupUpdated.
  ///
  /// In en, this message translates to:
  /// **'Group updated'**
  String get groupUpdated;

  /// No description provided for @notInGroup.
  ///
  /// In en, this message translates to:
  /// **'You\'re no longer in this group.'**
  String get notInGroup;

  /// No description provided for @typingOne.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing…'**
  String typingOne(String name);

  /// No description provided for @typingMany.
  ///
  /// In en, this message translates to:
  /// **'{names} are typing…'**
  String typingMany(String names);

  /// No description provided for @messageInfo.
  ///
  /// In en, this message translates to:
  /// **'Message info'**
  String get messageInfo;

  /// No description provided for @infoRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get infoRead;

  /// No description provided for @infoDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get infoDelivered;

  /// No description provided for @infoSent.
  ///
  /// In en, this message translates to:
  /// **'Sent, not delivered yet'**
  String get infoSent;

  /// No description provided for @infoNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody yet'**
  String get infoNobody;

  /// No description provided for @groupCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String groupCreatedBy(String name);

  /// No description provided for @groupMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembersTitle;

  /// No description provided for @changeGroupPhoto.
  ///
  /// In en, this message translates to:
  /// **'Change group photo'**
  String get changeGroupPhoto;

  /// No description provided for @errGroupGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the group. Please try again.'**
  String get errGroupGeneric;

  /// No description provided for @viewInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get viewInfo;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppL10nEn();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
