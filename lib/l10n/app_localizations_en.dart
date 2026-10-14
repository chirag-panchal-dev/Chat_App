// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Hushlo';

  @override
  String get loading => 'Loading';

  @override
  String get offlineBanner => 'You\'re offline. Messages will send when you reconnect.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get retry => 'Try again';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get send => 'Send';

  @override
  String get remove => 'Remove';

  @override
  String get search => 'Search';

  @override
  String get closeSearch => 'Close search';

  @override
  String get message => 'Message';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get reply => 'Reply';

  @override
  String get react => 'React';

  @override
  String get report => 'Report';

  @override
  String get block => 'Block';

  @override
  String get unblock => 'Unblock';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get moreOptions => 'More options';

  @override
  String get continueLabel => 'Continue';

  @override
  String get or => 'or';

  @override
  String get you => 'You';

  @override
  String get photo => 'Photo';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get unread => 'Unread';

  @override
  String get pinned => 'Pinned';

  @override
  String get muted => 'Muted';

  @override
  String get introHeadline => 'Good conversations, less noise.';

  @override
  String get introBody => 'A calm, private place to talk with the people you already know. No feed, no strangers.';

  @override
  String get getStarted => 'Get started';

  @override
  String get haveAccount => 'I already have an account';

  @override
  String get needAccount => 'New here? Create an account';

  @override
  String get createAccount => 'Create account';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetEmailSent => 'If an account exists for that email, a reset link is on its way.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String verifyEmailBody(String email) {
    return 'We sent a verification link to $email. Open it, then come back here.';
  }

  @override
  String get iVerified => 'I\'ve verified my email';

  @override
  String get resendEmail => 'Resend email';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get verificationSent => 'Verification email sent.';

  @override
  String get setupTitle => 'Set up your profile';

  @override
  String get chooseAvatar => 'Choose profile photo';

  @override
  String get avatarOptional => 'Photo (optional)';

  @override
  String get displayName => 'Display name';

  @override
  String get username => 'Username';

  @override
  String get bioOptional => 'Short bio (optional)';

  @override
  String get usernameHelp => '3–20 letters, numbers or underscores. Others find you by this exact name.';

  @override
  String get usernameAvailable => 'Username is available';

  @override
  String get usernameChecking => 'Checking…';

  @override
  String get usernameCheckFailed => 'Couldn\'t check right now. We\'ll verify when you continue.';

  @override
  String get usernameLocked => 'Usernames can\'t be changed in this version.';

  @override
  String get primerTitle => 'Before you start';

  @override
  String get primerDiscover => 'People can find you only by your exact username. There is no public directory.';

  @override
  String get primerStorage => 'Messages and photos are stored in the cloud so they sync and keep history.';

  @override
  String get primerNotifications => 'Notifications are optional and you control whether they show message text.';

  @override
  String get primerNotE2ee => 'Messages are protected in transit and by access rules, but they are not end-to-end encrypted.';

  @override
  String get chatsEmptyTitle => 'No conversations yet';

  @override
  String get chatsEmptyBody => 'Find a friend by their username and say hello.';

  @override
  String get startConversation => 'Start a conversation';

  @override
  String get newChat => 'New chat';

  @override
  String get searchChats => 'Search conversations';

  @override
  String get archivedChats => 'Archived chats';

  @override
  String archivedCount(int count) {
    return 'Archived ($count)';
  }

  @override
  String get noArchived => 'No archived chats.';

  @override
  String get noResults => 'No matching conversations.';

  @override
  String get notifPromptBody => 'Get notified when someone messages you.';

  @override
  String get turnOn => 'Turn on';

  @override
  String get deletedAccount => 'Deleted account';

  @override
  String get exactUsername => 'Exact username';

  @override
  String get searchHint => 'Enter someone\'s exact username to start a chat.';

  @override
  String get userNotFound => 'No one found with that username.';

  @override
  String get inviteFriend => 'Invite a friend';

  @override
  String inviteText(String username) {
    return 'Let\'s chat on Hushlo! My username is @$username.';
  }

  @override
  String get messageHint => 'Message';

  @override
  String get attachPhoto => 'Attach photo';

  @override
  String get chooseFromGallery => 'Gallery';

  @override
  String get takePhoto => 'Camera';

  @override
  String get cancelReply => 'Cancel reply';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get newMessages => 'New messages';

  @override
  String get chatEmptyTitle => 'Say hello';

  @override
  String chatEmptyBody(String name) {
    return 'This is the start of your conversation with $name.';
  }

  @override
  String get originalUnavailable => 'Original message unavailable';

  @override
  String get statusSending => 'Sending';

  @override
  String get statusSent => 'Sent';

  @override
  String get sendFailed => 'Couldn\'t send.';

  @override
  String get sendRejected => 'This message was rejected. You may not be able to message this person.';

  @override
  String get youBlocked => 'You blocked this account.';

  @override
  String get accountDeletedNotice => 'This account was deleted. You can\'t send new messages.';

  @override
  String blockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockBody => 'They won\'t be able to message you, and you won\'t be able to message them. You can unblock later in Settings.';

  @override
  String get photoPermissionDenied => 'Hushlo doesn\'t have permission to use the camera or photos.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get sendPhoto => 'Send photo';

  @override
  String get captionHint => 'Add a caption';

  @override
  String get uploading => 'Uploading';

  @override
  String get reportTitle => 'Report';

  @override
  String get reportBody => 'Tell us what\'s wrong. Reports are reviewed by our team and are never shown to the other person.';

  @override
  String get reportDetails => 'Additional details (optional)';

  @override
  String get reportSent => 'Thanks. Your report was sent.';

  @override
  String get reasonSpam => 'Spam';

  @override
  String get reasonHarassment => 'Harassment or bullying';

  @override
  String get reasonInappropriate => 'Inappropriate content';

  @override
  String get reasonImpersonation => 'Impersonation';

  @override
  String get reasonOther => 'Something else';

  @override
  String get settings => 'Settings';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsOn => 'Message notifications';

  @override
  String get notifDeniedHelp => 'Notifications are blocked in system settings.';

  @override
  String get showPreviews => 'Show message previews';

  @override
  String get showPreviewsHelp => 'Off by default. When off, notifications just say \"New message\".';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get privacyAndSafety => 'Privacy & safety';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get noBlockedTitle => 'No blocked users';

  @override
  String get noBlockedBody => 'People you block will appear here.';

  @override
  String get clearImageCache => 'Clear image cache';

  @override
  String get cacheCleared => 'Image cache cleared.';

  @override
  String get about => 'About';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get terms => 'Terms of service';

  @override
  String get communityGuidelines => 'Community guidelines';

  @override
  String get support => 'Support';

  @override
  String get account => 'Account';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get mute1h => 'Mute for 1 hour';

  @override
  String get mute8h => 'Mute for 8 hours';

  @override
  String get mute1w => 'Mute for 1 week';

  @override
  String get muteForever => 'Mute until I unmute';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteWhatTitle => 'What happens when you delete your account';

  @override
  String get deleteWhat1 => 'Your profile, username and settings are permanently deleted.';

  @override
  String get deleteWhat2 => 'Photos you uploaded and your notification tokens are deleted.';

  @override
  String get deleteWhat3 => 'Messages you sent are deleted from your conversations.';

  @override
  String get deleteWhat4 => 'The other person keeps their own messages; your name is replaced with \"Deleted account\".';

  @override
  String get deleteIrreversible => 'This can\'t be undone.';

  @override
  String get deleteConfirmCheck => 'I understand and want to delete my account';

  @override
  String get reauthExplain => 'For your security, please confirm it\'s you before we delete your account.';

  @override
  String get confirmAndDelete => 'Confirm and delete';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get errInvalidCredentials => 'That email or password isn\'t right.';

  @override
  String get errEmailInUse => 'An account with that email already exists.';

  @override
  String get errWeakPassword => 'Use a password with at least 8 characters.';

  @override
  String get errInvalidEmail => 'Enter a valid email address.';

  @override
  String get errUserDisabled => 'This account has been disabled.';

  @override
  String get errTooManyRequests => 'Too many attempts. Please wait a moment and try again.';

  @override
  String get errAccountExists => 'This email already uses a different sign-in method. Sign in with that method first.';

  @override
  String get errSignInCancelled => 'Sign-in was cancelled.';

  @override
  String get errReauthRequired => 'Please sign in again to continue.';

  @override
  String get errEmailNotVerified => 'Please verify your email first.';

  @override
  String get errNetwork => 'No connection. Check your network and try again.';

  @override
  String get errPermission => 'You don\'t have permission to do that.';

  @override
  String get errUsernameInvalid => 'Use 3–20 letters, numbers or underscores.';

  @override
  String get errUsernameTaken => 'That username is taken.';

  @override
  String get errDisplayNameInvalid => 'Enter a display name (up to 50 characters).';

  @override
  String get errMessageEmpty => 'Write a message first.';

  @override
  String get errMessageTooLong => 'That message is too long.';

  @override
  String get errFileTooLarge => 'That file is too large (max 10 MB).';

  @override
  String get errFileUnsupported => 'That file type isn\'t supported. Use JPG, PNG, WebP or HEIC.';

  @override
  String get errSelfConversation => 'You can\'t start a chat with yourself.';

  @override
  String get errUploadCancelled => 'Upload cancelled.';

  @override
  String get errUploadFailed => 'Upload failed. Please try again.';

  @override
  String errUnknown(String id) {
    return 'Something unexpected happened. Reference: $id';
  }

  @override
  String get noPreview => 'Tap to open the chat';

  @override
  String get readReceipts => 'Read receipts';

  @override
  String get readReceiptsHelp => 'If you turn this off, you won\'t send or see read receipts. Delivery ticks still work.';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusRead => 'Read';

  @override
  String get tapForInfo => 'Tap here for contact info';

  @override
  String get chatPrivacyNote => 'Messages are stored in the cloud and protected by access rules. They are not end-to-end encrypted.';

  @override
  String get contactInfo => 'Contact info';

  @override
  String get sharedPhotos => 'Shared photos';

  @override
  String get noSharedPhotos => 'No photos shared yet.';

  @override
  String get bioEmpty => 'No bio yet.';

  @override
  String get viewPhoto => 'View photo';

  @override
  String get filterAll => 'All';

  @override
  String get filterUnread => 'Unread';

  @override
  String get filterPinned => 'Pinned';

  @override
  String get chats => 'Chats';

  @override
  String get photoPreview => 'Photo';

  @override
  String get settingsSubtitle => 'Account, privacy and appearance';

  @override
  String get featurePrivate => 'Find people only by their exact username';

  @override
  String get featureCalm => 'Calm notifications you control';

  @override
  String get featureNoFeed => 'No feed. No strangers. Just your circle.';

  @override
  String get welcomeTagline => 'Chat with your circle';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get online => 'online';

  @override
  String lastSeenToday(String time) {
    return 'last seen today at $time';
  }

  @override
  String lastSeenYesterday(String time) {
    return 'last seen yesterday at $time';
  }

  @override
  String lastSeenOn(String date) {
    return 'last seen $date';
  }

  @override
  String get showLastSeen => 'Last seen & online';

  @override
  String get showLastSeenHelp => 'If you turn this off, others can\'t see when you were last online or when you\'re typing, and you can\'t see theirs.';

  @override
  String get messageDeleted => 'This message was deleted';

  @override
  String get youDeletedMessage => 'You deleted this message';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String deleteMessagesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count messages?',
      one: 'Delete message?',
    );
    return '$_temp0';
  }

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String get deleteForMeOnly => 'Delete for me';

  @override
  String get deleteForEveryoneHelp => 'Removes the content for everyone in this chat. Only possible within 48 hours.';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody => 'Your messages stay safe in your account. You\'ll need to sign in again to read them.';

  @override
  String get deleteReasonTitle => 'Why are you leaving?';

  @override
  String get deleteReasonHelp => 'Optional. This is anonymous and helps us improve.';

  @override
  String get reasonAnotherAccount => 'I have another account';

  @override
  String get reasonPrivacy => 'Privacy concerns';

  @override
  String get reasonNotUsing => 'I\'m not using Hushlo';

  @override
  String get reasonNotifications => 'Too many notifications';

  @override
  String get reasonBetterApp => 'I found a better app';

  @override
  String get reasonOtherLeave => 'Something else';

  @override
  String get deleteReasonDetails => 'Tell us more (optional)';

  @override
  String get copyMessages => 'Copy';

  @override
  String get cancelSelection => 'Cancel selection';

  @override
  String blockUser(String name) {
    return 'Block $name';
  }

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get goToOriginal => 'Go to original message';

  @override
  String get removeReaction => 'Remove reaction';

  @override
  String get typing => 'typing…';

  @override
  String get clearChat => 'Clear chat';

  @override
  String get clearChatTitle => 'Clear this chat?';

  @override
  String clearChatBody(String name) {
    return 'All messages will be removed from your view. $name keeps their copy.';
  }

  @override
  String get clearAction => 'Clear';

  @override
  String get chatCleared => 'Chat cleared';

  @override
  String get startSheetTitle => 'Start something new';

  @override
  String get newChatDesc => 'Message someone by their username';

  @override
  String get newGroup => 'New group';

  @override
  String newGroupDesc(int max) {
    return 'Chat with up to $max people';
  }

  @override
  String get joinWithCode => 'Join with a code';

  @override
  String get joinWithCodeDesc => 'Use an invite code from a group admin';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get addMembers => 'Add members';

  @override
  String get selectMembers => 'Select members';

  @override
  String membersSelected(int count, int max) {
    return '$count of $max selected';
  }

  @override
  String get searchYourChats => 'Search your chats';

  @override
  String get addByUsername => 'Add by username';

  @override
  String get noContactsYet => 'No chats yet. Add people by their exact username below.';

  @override
  String get groupName => 'Group name';

  @override
  String get groupNameHint => 'Name your group';

  @override
  String get groupPhotoOptional => 'Group photo (optional)';

  @override
  String get createGroup => 'Create group';

  @override
  String get next => 'Next';

  @override
  String get groupInfo => 'Group info';

  @override
  String get admin => 'Admin';

  @override
  String get youLower => 'you';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get removeAdmin => 'Remove as admin';

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get leaveGroupTitle => 'Leave this group?';

  @override
  String leaveGroupBody(String name) {
    return 'You won\'t get new messages from $name. To come back, an admin has to approve you again.';
  }

  @override
  String removeMemberTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeMemberBody => 'They won\'t see new messages in this group.';

  @override
  String get editGroupName => 'Edit group name';

  @override
  String groupFull(int max) {
    return 'This group is full (up to $max people).';
  }

  @override
  String get cannotRemoveLastAdmin => 'Make someone else an admin first.';

  @override
  String memberLimitReached(int max) {
    return 'Groups can have up to $max people.';
  }

  @override
  String get onlyAdminsCan => 'Only admins can do this.';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get inviteCodeHelp => 'Share this code. People who use it can ask to join; an admin approves them.';

  @override
  String get createInviteCode => 'Create invite code';

  @override
  String get resetInviteCode => 'Create a new code';

  @override
  String get turnOffInvite => 'Turn off';

  @override
  String get copyCode => 'Copy code';

  @override
  String get shareCode => 'Share';

  @override
  String inviteShareText(String name, String code) {
    return 'Join \"$name\" on Hushlo. Use this invite code: $code';
  }

  @override
  String get codeCopied => 'Code copied';

  @override
  String get noActiveInvite => 'No active invite code.';

  @override
  String get joinRequests => 'Join requests';

  @override
  String get noJoinRequests => 'No pending requests.';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String requestsPending(int count) {
    return '$count pending';
  }

  @override
  String get joinGroupTitle => 'Join a group';

  @override
  String get enterInviteCode => 'Invite code';

  @override
  String get pasteCode => 'Paste';

  @override
  String get findGroup => 'Find group';

  @override
  String get invalidInviteCode => 'That code isn\'t valid or has been turned off.';

  @override
  String get requestToJoin => 'Request to join';

  @override
  String get requestSent => 'Request sent. An admin needs to approve it.';

  @override
  String get alreadyMember => 'You\'re already in this group.';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get joinGroupHelp => 'Ask a group admin for an invite code, then enter it here.';

  @override
  String sysAdded(String actor, String target) {
    return '$actor added $target';
  }

  @override
  String sysRemoved(String actor, String target) {
    return '$actor removed $target';
  }

  @override
  String sysLeft(String actor) {
    return '$actor left';
  }

  @override
  String sysRenamed(String actor) {
    return '$actor changed the group name';
  }

  @override
  String get groupUpdated => 'Group updated';

  @override
  String get notInGroup => 'You\'re no longer in this group.';

  @override
  String typingOne(String name) {
    return '$name is typing…';
  }

  @override
  String typingMany(String names) {
    return '$names are typing…';
  }

  @override
  String get messageInfo => 'Message info';

  @override
  String get infoRead => 'Read';

  @override
  String get infoDelivered => 'Delivered';

  @override
  String get infoSent => 'Sent, not delivered yet';

  @override
  String get infoNobody => 'Nobody yet';

  @override
  String groupCreatedBy(String name) {
    return 'Created by $name';
  }

  @override
  String get groupMembersTitle => 'Members';

  @override
  String get changeGroupPhoto => 'Change group photo';

  @override
  String get errGroupGeneric => 'Couldn\'t update the group. Please try again.';

  @override
  String get viewInfo => 'Info';
}
