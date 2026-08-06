// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionGo => 'Go';

  @override
  String get actionEnable => 'Enable';

  @override
  String get actionDisable => 'Disable';

  @override
  String get actionDone => 'Done';

  @override
  String get loginCreateAccount => 'Create account';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get fieldEmail => 'Email';

  @override
  String get validatorEmailInvalid => 'Enter a valid email';

  @override
  String get fieldName => 'Name';

  @override
  String get validatorNameRequired => 'Name is required';

  @override
  String get fieldSurnameOptional => 'Surname (optional)';

  @override
  String get fieldUsername => 'Username';

  @override
  String get usernameHelperText => 'How friends find you to add you';

  @override
  String get validatorUsernameTooShort => 'At least 3 characters';

  @override
  String get validatorUsernameFormat =>
      'Letters, numbers, and underscores only';

  @override
  String get fieldPassword => 'Password';

  @override
  String get validatorPasswordTooShort => 'At least 8 characters';

  @override
  String get validatorPasswordTooLong => 'At most 72 characters';

  @override
  String get validatorPasswordRequired => 'Enter your password';

  @override
  String get validatorPasswordPolicy =>
      'Must include a lowercase letter, an uppercase letter, a number, and a symbol';

  @override
  String get passwordRequirementsHint =>
      'At least 8 characters, with uppercase, lowercase, a number, and a symbol';

  @override
  String get loginRegisterButton => 'Register';

  @override
  String get loginLoginButton => 'Login';

  @override
  String get loginToggleToSignIn => 'Already have an account? Sign in';

  @override
  String get loginToggleToRegister => 'Need an account? Register';

  @override
  String get loginKeepMeSignedIn => 'Keep me signed in';

  @override
  String get loginKeepMeSignedInSubtitle =>
      'Turn off on a shared computer so the next person doesn\'t open your calendar';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String verifyEmailSubtitle(String email) {
    return 'We sent a 6-digit code to $email. Enter it below to finish setting up your account.';
  }

  @override
  String get fieldVerificationCode => 'Verification code';

  @override
  String get validatorCodeInvalid => 'Enter the 6-digit code';

  @override
  String get verifyEmailButton => 'Verify';

  @override
  String get verifyEmailResend => 'Resend code';

  @override
  String get verifyEmailResendSent => 'Code sent — check your inbox';

  @override
  String get verifyEmailBackToSignIn => 'Back to sign in';

  @override
  String get twoFactorLoginTitle => 'Two-factor authentication';

  @override
  String get twoFactorLoginSubtitle =>
      'Enter the 6-digit code from your authenticator app';

  @override
  String twoFactorEmailSubtitle(String email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get twoFactorBackupSubtitle => 'Enter one of your backup codes';

  @override
  String get fieldTwoFactorCode => 'Authentication code';

  @override
  String get fieldBackupCode => 'Backup code';

  @override
  String get validatorTwoFactorCodeInvalid => 'Enter a valid code';

  @override
  String get twoFactorUseBackupCode => 'Use a backup code instead';

  @override
  String get twoFactorUseAuthenticatorApp =>
      'Use your authenticator app instead';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your account email and we\'ll send you a reset code.';

  @override
  String get forgotPasswordSendButton => 'Send reset code';

  @override
  String get forgotPasswordBackToSignIn => 'Back to sign in';

  @override
  String get resetPasswordTitle => 'Enter reset code';

  @override
  String resetPasswordSubtitle(String email) {
    return 'We sent a 6-digit code to $email. Enter it below along with your new password.';
  }

  @override
  String get fieldNewPassword => 'New password';

  @override
  String get resetPasswordButton => 'Reset password';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String eventsLoadError(String error) {
    return 'Failed to load events: $error';
  }

  @override
  String get tooltipSettings => 'Settings';

  @override
  String get tooltipSignOut => 'Sign out';

  @override
  String get tooltipHideEsc => 'Hide (Esc)';

  @override
  String get tooltipNotifications => 'Notifications';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String get actionViewAllNotifications => 'View all notifications';

  @override
  String get notificationsScreenTitle => 'Notifications';

  @override
  String get tooltipFriendsGroups => 'Friends & Groups';

  @override
  String get goToMonthTitle => 'Go to month';

  @override
  String get noEventsOnThisDay => 'No events on this day';

  @override
  String get anytime => 'Anytime';

  @override
  String get somedayHeader => 'Someday...';

  @override
  String get addSomedayHint => 'Add something for someday...';

  @override
  String get dragIdeasHint => 'Drag ideas onto a day when you\'re ready';

  @override
  String get allDay => 'All day';

  @override
  String durationTbd(String time) {
    return '$time (duration TBD)';
  }

  @override
  String get tooltipHasDescription => 'Has a description';

  @override
  String get tooltipRepeats => 'Repeats — edit to change the series';

  @override
  String get tooltipNotSynced => 'Not yet synced';

  @override
  String notificationFriendRequestReceived(String name) {
    return '$name sent you a friend request';
  }

  @override
  String notificationFriendRequestAccepted(String name) {
    return '$name accepted your friend request';
  }

  @override
  String notificationLeftEvent(String name, String event) {
    return '$name left \"$event\"';
  }

  @override
  String notificationInviteAccepted(String name, String event) {
    return '$name accepted your invite to \"$event\"';
  }

  @override
  String notificationInviteDeclined(String name, String event) {
    return '$name declined your invite to \"$event\"';
  }

  @override
  String notificationDateChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  ) {
    return '$name changed the date of \"$event\" from $oldValue to $newValue';
  }

  @override
  String notificationTimeChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  ) {
    return '$name changed the time of \"$event\" from $oldValue to $newValue';
  }

  @override
  String notificationLocationChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  ) {
    return '$name changed the location of \"$event\" from $oldValue to $newValue';
  }

  @override
  String notificationDescriptionChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  ) {
    return '$name changed the description of \"$event\" from \"$oldValue\" to \"$newValue\"';
  }

  @override
  String get notificationEmptyValue => 'none';

  @override
  String get actionLeaveEvent => 'Leave event';

  @override
  String get leaveEventDialogTitle => 'Leave this event?';

  @override
  String get leaveEventDialogMessage =>
      'You\'ll stop seeing this on your calendar, and the organizer and other participants will be notified that you left.';

  @override
  String get sectionConfirmations => 'Confirmations';

  @override
  String get sectionOtherNotifications => 'Other notifications';

  @override
  String get otherNotificationsSubtitle =>
      'Friend requests, event invites, and updates to events shared with you';

  @override
  String get notificationSoundEnabledLabel => 'Play a sound';

  @override
  String get notificationVolumeLabel => 'Volume';

  @override
  String get reminderVolumeLabel => 'Volume';

  @override
  String get actionDontAskAgain => 'Don\'t ask me again';

  @override
  String get confirmBeforeLeavingEventLabel =>
      'Confirm before leaving a shared event';

  @override
  String get confirmBeforeLeavingEventSubtitle =>
      'Show a confirmation dialog when you leave an event someone else invited you to';

  @override
  String get eventFormEditTitle => 'Edit event';

  @override
  String get eventFormNewTitle => 'New event';

  @override
  String get sharedWithYou => 'Shared with you';

  @override
  String sharedByOwner(String ownerName) {
    return 'Shared by $ownerName';
  }

  @override
  String tooltipSharedEvent(String ownerName) {
    return 'Shared by $ownerName';
  }

  @override
  String get alsoSharedWithHeader => 'Also shared with';

  @override
  String get pendingInviteBadge => 'Invite pending';

  @override
  String get pendingInviteScreenTitle => 'Event invite';

  @override
  String pendingInviteMessage(String ownerName) {
    return '$ownerName invited you to this event.';
  }

  @override
  String get actionAccept => 'Accept';

  @override
  String get actionDecline => 'Decline';

  @override
  String inviteRespondFailed(String error) {
    return 'Couldn\'t respond to the invite: $error';
  }

  @override
  String get fieldTitle => 'Title';

  @override
  String get validatorTitleRequired => 'Title is required';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldLocation => 'Location';

  @override
  String get fieldDay => 'Day';

  @override
  String get actionNoSpecificTime => 'No specific time';

  @override
  String get actionAddATime => 'Add a time';

  @override
  String get labelStart => 'Start';

  @override
  String get labelEnd => 'End';

  @override
  String get fieldRepeat => 'Repeat';

  @override
  String get repeatNone => 'Does not repeat';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String get everyWord => 'Every';

  @override
  String repeatUnitDay(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitWeek(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'weeks',
      one: 'week',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitMonth(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitYear(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'years',
      one: 'year',
    );
    return '$_temp0';
  }

  @override
  String get endsWord => 'Ends';

  @override
  String get repeatEndNever => 'Never';

  @override
  String get repeatEndOnDate => 'On date';

  @override
  String repeatEndOnDateWithValue(String date) {
    return 'On date ($date)';
  }

  @override
  String repeatEndAfterCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'After $count occurrences',
      one: 'After $count occurrence',
    );
    return '$_temp0';
  }

  @override
  String get occurrencesLabel => 'Occurrences:';

  @override
  String get seriesChangeNotice => 'Changes apply to the entire series.';

  @override
  String get remindersHeader => 'Reminders';

  @override
  String get actionCustom => 'Custom';

  @override
  String get reminderAtStartTime => 'At start time';

  @override
  String reminderMinutesBefore(num minutes) {
    return '$minutes min before';
  }

  @override
  String reminderDaysBefore(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String reminderHoursBefore(num hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours before',
      one: '1 hour before',
    );
    return '$_temp0';
  }

  @override
  String get customReminderDialogTitle => 'Remind me before';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get unitMinutes => 'Minutes';

  @override
  String get unitHours => 'Hours';

  @override
  String get unitDays => 'Days';

  @override
  String get actionSaveChanges => 'Save changes';

  @override
  String get actionCreateEvent => 'Create event';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsCategoryGeneral => 'General';

  @override
  String get settingsCategoryGeneralSubtitle => 'Theme, language, and startup';

  @override
  String get settingsCategoryCalendar => 'Calendar';

  @override
  String get settingsCategoryCalendarSubtitle => 'Which day the week starts on';

  @override
  String get settingsCategoryVoiceInput => 'Voice input';

  @override
  String get settingsCategoryVoiceInputSubtitle =>
      'Microphone used by the assistant';

  @override
  String get settingsCategoryReminders => 'Reminders';

  @override
  String get settingsCategoryRemindersSubtitle =>
      'Notification channel and sounds';

  @override
  String get settingsCategoryAccount => 'Account';

  @override
  String get settingsCategoryAccountSubtitle =>
      'Email, username, password, and account deletion';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionCalendar => 'Calendar';

  @override
  String get sectionReminders => 'Reminders';

  @override
  String get sectionStartup => 'Startup';

  @override
  String get launchAtLogin => 'Launch at login';

  @override
  String get launchAtLoginSubtitle =>
      'Start Calendar App minimized to the tray when you sign in to Windows, so reminders keep firing';

  @override
  String get sectionAccount => 'Account';

  @override
  String get changeUsernameDialogTitle => 'Change username';

  @override
  String get changeEmailDialogTitle => 'Change email';

  @override
  String get changePasswordDialogTitle => 'Change password';

  @override
  String get fieldNewUsername => 'New username';

  @override
  String get fieldNewEmail => 'New email';

  @override
  String get fieldCurrentPassword => 'Current password';

  @override
  String get verifyNewEmailDialogTitle => 'Verify your new email';

  @override
  String verifyNewEmailMessage(String email) {
    return 'Enter the code sent to $email';
  }

  @override
  String get usernameChangedMessage => 'Username changed';

  @override
  String get passwordChangedMessage => 'Password changed';

  @override
  String get emailChangedMessage => 'Email changed';

  @override
  String get sectionTwoFactorAuth => 'Two-factor authentication';

  @override
  String get twoFactorStatusEnabled => 'Enabled';

  @override
  String get twoFactorStatusDisabled => 'Disabled';

  @override
  String get twoFactorSectionSubtitle =>
      'Add an extra layer of security to your account';

  @override
  String get twoFactorChooseMethodTitle => 'Choose a method';

  @override
  String get twoFactorMethodAuthenticatorApp => 'Authenticator app';

  @override
  String get twoFactorMethodEmail => 'Email code';

  @override
  String get twoFactorSetupDialogTitle => 'Set up authenticator app';

  @override
  String get twoFactorSetupInstructions =>
      'Scan this QR code with your authenticator app, or enter the code manually.';

  @override
  String get twoFactorEmailSetupDialogTitle => 'Set up email codes';

  @override
  String get twoFactorEmailSetupInstructions =>
      'Enter the code we just emailed you to confirm.';

  @override
  String get twoFactorSendCodeToEmail => 'Send code to my email';

  @override
  String get twoFactorBackupCodesDialogTitle => 'Save your backup codes';

  @override
  String get twoFactorBackupCodesWarning =>
      'Each code can be used once if you lose access to your authenticator app or email. Store them somewhere safe — they won\'t be shown again.';

  @override
  String get twoFactorBackupCodesConfirmCheckbox =>
      'I\'ve saved these codes somewhere safe';

  @override
  String get twoFactorDisableDialogTitle => 'Disable two-factor authentication';

  @override
  String get twoFactorDisableCodeHint =>
      'Your current code, or one of your backup codes if you\'ve lost access to it';

  @override
  String get sectionDangerZone => 'Danger zone';

  @override
  String get actionDeleteAccount => 'Delete account';

  @override
  String get deleteAccountDialogTitle => 'Delete your account?';

  @override
  String get deleteAccountWarning =>
      'This permanently deletes your account. Events, groups, and friendships that are only yours are removed entirely; anything shared with other people (like an event they accepted) is kept, with your identity anonymized. This can\'t be undone. Enter your password to confirm.';

  @override
  String get deleteAccountConfirmButton => 'Delete my account';

  @override
  String get sectionLanguage => 'Language';

  @override
  String weekStartsOn(String day) {
    return 'Week starts on $day';
  }

  @override
  String get enableReminderNotifications => 'Enable reminder notifications';

  @override
  String get inAppPopup => 'In-app popup';

  @override
  String get inAppPopupSubtitle => 'A small window from Calendar App itself';

  @override
  String get windowsNotification => 'Windows notification';

  @override
  String get windowsNotificationSubtitle =>
      'The OS notification, matches other apps';

  @override
  String get popupPosition => 'Popup position';

  @override
  String get popupDuration => 'Popup duration';

  @override
  String get soundSectionLabel => 'Sound';

  @override
  String get soundFileFormatsHint => 'mp3, wav, ogg, m4a...';

  @override
  String get noFileChosen => 'No file chosen';

  @override
  String get actionChooseFile => 'Choose file...';

  @override
  String get actionChange => 'Change';

  @override
  String get tooltipPreview => 'Preview';

  @override
  String get actionSendTestReminder => 'Send a test reminder';

  @override
  String get dialogChooseReminderSound => 'Choose a reminder sound';

  @override
  String get testReminderTitle => 'Test reminder';

  @override
  String get testReminderBody => 'This is what your reminders will look like.';

  @override
  String get themeSystem => 'Match system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get weekdayMonday => 'Monday';

  @override
  String get weekdayTuesday => 'Tuesday';

  @override
  String get weekdayWednesday => 'Wednesday';

  @override
  String get weekdayThursday => 'Thursday';

  @override
  String get weekdayFriday => 'Friday';

  @override
  String get weekdaySaturday => 'Saturday';

  @override
  String get weekdaySunday => 'Sunday';

  @override
  String get soundNone => 'No sound';

  @override
  String get soundClick => 'Click';

  @override
  String get soundAlert => 'Alert';

  @override
  String get soundCustom => 'Custom sound file';

  @override
  String get cornerTopLeft => 'Top left';

  @override
  String get cornerTopRight => 'Top right';

  @override
  String get cornerBottomLeft => 'Bottom left';

  @override
  String get cornerBottomRight => 'Bottom right';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get socialTitle => 'Friends & Groups';

  @override
  String get tabFriends => 'Friends';

  @override
  String get tabRequests => 'Requests';

  @override
  String get tabGroups => 'Groups';

  @override
  String get tabInvites => 'Invites';

  @override
  String get searchByUsername => 'Search by username';

  @override
  String get noFriendsYetHint => 'No friends yet — search a username above';

  @override
  String get tooltipRemoveFriend => 'Remove friend';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get relationshipFriends => 'Friends';

  @override
  String get relationshipRequested => 'Requested';

  @override
  String get relationshipCheckRequestsTab => 'Check Requests tab';

  @override
  String get sectionIncoming => 'Incoming';

  @override
  String get noIncomingRequests => 'No incoming requests';

  @override
  String get sectionSent => 'Sent';

  @override
  String get noPendingSentRequests => 'No pending sent requests';

  @override
  String get sectionMyGroups => 'My groups';

  @override
  String get sectionGroupsImIn => 'Groups I\'m in';

  @override
  String get noGroupsYetHint => 'No groups yet — create one below';

  @override
  String get notInAnyGroupsHint => 'You\'re not in any groups';

  @override
  String groupOwnedBy(String name) {
    return 'Owned by $name';
  }

  @override
  String memberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String get actionAddMember => 'Add member';

  @override
  String get actionRename => 'Rename';

  @override
  String get dialogAddFriendTitle => 'Add a friend';

  @override
  String get addFriendsFirstHint => 'Add some friends first';

  @override
  String get dialogNewGroupTitle => 'New group';

  @override
  String get dialogRenameGroupTitle => 'Rename group';

  @override
  String get fieldGroupName => 'Group name';

  @override
  String get noPendingEventInvites => 'No pending event invites';

  @override
  String inviteSubtitle(String name, String when) {
    return 'From $name · $when';
  }

  @override
  String get noSpecificTimeLabel => 'No specific time';

  @override
  String get statusPending => 'pending';

  @override
  String get statusAccepted => 'accepted';

  @override
  String get statusDeclined => 'declined';

  @override
  String get peopleHeader => 'People';

  @override
  String get noOneElseInvited => 'No one else invited yet';

  @override
  String get tooltipRemove => 'Remove';

  @override
  String get actionAddPeople => 'Add people';

  @override
  String get actionAddGroups => 'Add groups';

  @override
  String get dialogAddPeopleTitle => 'Add people';

  @override
  String get dialogAddGroupsTitle => 'Add groups';

  @override
  String get noGroupsToPickHint => 'You don\'t have any groups yet';

  @override
  String get searchHint => 'Search';

  @override
  String get noResultsForSearch => 'No matches';

  @override
  String get willBeSentOnSave => 'Will be sent when you save';

  @override
  String inviteApplyFailed(String error) {
    return 'Event saved, but invites couldn\'t be sent: $error';
  }

  @override
  String get dialogChooseFileToAttach => 'Choose a file to attach';

  @override
  String get attachmentsHeader => 'Attachments';

  @override
  String get actionAddFile => 'Add file';

  @override
  String get noAttachmentsYet => 'No attachments yet';

  @override
  String get tooltipDeleteAttachment => 'Delete';

  @override
  String failedToLoadGeneric(String error) {
    return 'Failed to load: $error';
  }

  @override
  String failedToLoadFriends(String error) {
    return 'Failed to load friends: $error';
  }

  @override
  String failedToLoadGroups(String error) {
    return 'Failed to load groups: $error';
  }

  @override
  String failedToLoadInvites(String error) {
    return 'Failed to load invites: $error';
  }

  @override
  String failedToLoadAttachments(String error) {
    return 'Failed to load attachments: $error';
  }

  @override
  String get editRecurringEventTitle => 'Edit recurring event';

  @override
  String get deleteRecurringEventTitle => 'Delete recurring event';

  @override
  String get scopeThisEvent => 'This event';

  @override
  String get scopeAllEvents => 'All events';

  @override
  String repeatMonthlyByDay(int day) {
    return 'Monthly on day $day';
  }

  @override
  String repeatMonthlyByWeekday(String ordinal, String weekday) {
    return 'Monthly on the $ordinal $weekday';
  }

  @override
  String get ordinalFirst => 'first';

  @override
  String get ordinalSecond => 'second';

  @override
  String get ordinalThird => 'third';

  @override
  String get ordinalFourth => 'fourth';

  @override
  String get ordinalLast => 'last';

  @override
  String get sectionVoiceInput => 'Voice input';

  @override
  String get fieldMicrophone => 'Microphone';

  @override
  String get microphoneSubtitle =>
      'If voice commands aren\'t being picked up, pick the microphone you actually speak into — the system default isn\'t always the right one on machines with several.';

  @override
  String get microphoneSystemDefault => 'System default';

  @override
  String get microphoneListError => 'Couldn\'t list microphones.';

  @override
  String get actionTestMicrophone => 'Test microphone';

  @override
  String get actionStopMicTest => 'Stop test';

  @override
  String get tooltipAssistant => 'Assistant';

  @override
  String get tooltipAddEvent => 'Add event';

  @override
  String get assistantTitle => 'Assistant';

  @override
  String get assistantInputHint =>
      'Ask me to schedule, find, or change something...';

  @override
  String get assistantRecordingHint => 'Listening... tap the mic again to stop';

  @override
  String get assistantTranscribingHint => 'Transcribing...';

  @override
  String get assistantEmptyState =>
      'Ask me to schedule, find, or change something on your calendar.';

  @override
  String assistantConfirmDeleteCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete these $count events?',
      one: 'Delete this event?',
    );
    return '$_temp0';
  }

  @override
  String assistantDeletedConfirmation(String title) {
    return 'Deleted \"$title\".';
  }

  @override
  String assistantErrorGeneric(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String reminderStartingNow(String title) {
    return '$title is starting now';
  }

  @override
  String reminderWithLabel(String title, String label) {
    return '$title — $label';
  }
}
