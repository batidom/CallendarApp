import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get actionGo;

  /// No description provided for @loginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get loginCreateAccount;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSignIn;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @validatorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validatorEmailInvalid;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @validatorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get validatorNameRequired;

  /// No description provided for @fieldSurnameOptional.
  ///
  /// In en, this message translates to:
  /// **'Surname (optional)'**
  String get fieldSurnameOptional;

  /// No description provided for @fieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// No description provided for @usernameHelperText.
  ///
  /// In en, this message translates to:
  /// **'How friends find you to add you'**
  String get usernameHelperText;

  /// No description provided for @validatorUsernameTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 3 characters'**
  String get validatorUsernameTooShort;

  /// No description provided for @validatorUsernameFormat.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers, and underscores only'**
  String get validatorUsernameFormat;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @validatorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get validatorPasswordTooShort;

  /// No description provided for @loginRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get loginRegisterButton;

  /// No description provided for @loginLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginLoginButton;

  /// No description provided for @loginToggleToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get loginToggleToSignIn;

  /// No description provided for @loginToggleToRegister.
  ///
  /// In en, this message translates to:
  /// **'Need an account? Register'**
  String get loginToggleToRegister;

  /// No description provided for @loginKeepMeSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in'**
  String get loginKeepMeSignedIn;

  /// No description provided for @loginKeepMeSignedInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off on a shared computer so the next person doesn\'t open your calendar'**
  String get loginKeepMeSignedInSubtitle;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}. Enter it below to finish setting up your account.'**
  String verifyEmailSubtitle(String email);

  /// No description provided for @fieldVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get fieldVerificationCode;

  /// No description provided for @validatorCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get validatorCodeInvalid;

  /// No description provided for @verifyEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyEmailButton;

  /// No description provided for @verifyEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get verifyEmailResend;

  /// No description provided for @verifyEmailResendSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent — check your inbox'**
  String get verifyEmailResendSent;

  /// No description provided for @verifyEmailBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get verifyEmailBackToSignIn;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we\'ll send you a reset code.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotPasswordSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get forgotPasswordSendButton;

  /// No description provided for @forgotPasswordBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get forgotPasswordBackToSignIn;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter reset code'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}. Enter it below along with your new password.'**
  String resetPasswordSubtitle(String email);

  /// No description provided for @fieldNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get fieldNewPassword;

  /// No description provided for @resetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordButton;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @eventsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load events: {error}'**
  String eventsLoadError(String error);

  /// No description provided for @tooltipSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tooltipSettings;

  /// No description provided for @tooltipSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get tooltipSignOut;

  /// No description provided for @tooltipHideEsc.
  ///
  /// In en, this message translates to:
  /// **'Hide (Esc)'**
  String get tooltipHideEsc;

  /// No description provided for @tooltipNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get tooltipNotifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @actionViewAllNotifications.
  ///
  /// In en, this message translates to:
  /// **'View all notifications'**
  String get actionViewAllNotifications;

  /// No description provided for @notificationsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsScreenTitle;

  /// No description provided for @tooltipFriendsGroups.
  ///
  /// In en, this message translates to:
  /// **'Friends & Groups'**
  String get tooltipFriendsGroups;

  /// No description provided for @goToMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'Go to month'**
  String get goToMonthTitle;

  /// No description provided for @noEventsOnThisDay.
  ///
  /// In en, this message translates to:
  /// **'No events on this day'**
  String get noEventsOnThisDay;

  /// No description provided for @anytime.
  ///
  /// In en, this message translates to:
  /// **'Anytime'**
  String get anytime;

  /// No description provided for @somedayHeader.
  ///
  /// In en, this message translates to:
  /// **'Someday...'**
  String get somedayHeader;

  /// No description provided for @addSomedayHint.
  ///
  /// In en, this message translates to:
  /// **'Add something for someday...'**
  String get addSomedayHint;

  /// No description provided for @dragIdeasHint.
  ///
  /// In en, this message translates to:
  /// **'Drag ideas onto a day when you\'re ready'**
  String get dragIdeasHint;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDay;

  /// No description provided for @durationTbd.
  ///
  /// In en, this message translates to:
  /// **'{time} (duration TBD)'**
  String durationTbd(String time);

  /// No description provided for @tooltipHasDescription.
  ///
  /// In en, this message translates to:
  /// **'Has a description'**
  String get tooltipHasDescription;

  /// No description provided for @tooltipRepeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats — edit to change the series'**
  String get tooltipRepeats;

  /// No description provided for @tooltipNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Not yet synced'**
  String get tooltipNotSynced;

  /// No description provided for @notificationFriendRequestReceived.
  ///
  /// In en, this message translates to:
  /// **'{name} sent you a friend request'**
  String notificationFriendRequestReceived(String name);

  /// No description provided for @notificationFriendRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your friend request'**
  String notificationFriendRequestAccepted(String name);

  /// No description provided for @notificationLeftEvent.
  ///
  /// In en, this message translates to:
  /// **'{name} left \"{event}\"'**
  String notificationLeftEvent(String name, String event);

  /// No description provided for @notificationInviteAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your invite to \"{event}\"'**
  String notificationInviteAccepted(String name, String event);

  /// No description provided for @notificationInviteDeclined.
  ///
  /// In en, this message translates to:
  /// **'{name} declined your invite to \"{event}\"'**
  String notificationInviteDeclined(String name, String event);

  /// No description provided for @notificationDateChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} changed the date of \"{event}\" from {oldValue} to {newValue}'**
  String notificationDateChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  );

  /// No description provided for @notificationTimeChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} changed the time of \"{event}\" from {oldValue} to {newValue}'**
  String notificationTimeChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  );

  /// No description provided for @notificationLocationChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} changed the location of \"{event}\" from {oldValue} to {newValue}'**
  String notificationLocationChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  );

  /// No description provided for @notificationDescriptionChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} changed the description of \"{event}\" from \"{oldValue}\" to \"{newValue}\"'**
  String notificationDescriptionChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  );

  /// No description provided for @notificationEmptyValue.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get notificationEmptyValue;

  /// No description provided for @actionLeaveEvent.
  ///
  /// In en, this message translates to:
  /// **'Leave event'**
  String get actionLeaveEvent;

  /// No description provided for @leaveEventDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this event?'**
  String get leaveEventDialogTitle;

  /// No description provided for @leaveEventDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ll stop seeing this on your calendar, and the organizer and other participants will be notified that you left.'**
  String get leaveEventDialogMessage;

  /// No description provided for @sectionConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get sectionConfirmations;

  /// No description provided for @sectionOtherNotifications.
  ///
  /// In en, this message translates to:
  /// **'Other notifications'**
  String get sectionOtherNotifications;

  /// No description provided for @otherNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Friend requests, event invites, and updates to events shared with you'**
  String get otherNotificationsSubtitle;

  /// No description provided for @notificationSoundEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Play a sound'**
  String get notificationSoundEnabledLabel;

  /// No description provided for @actionDontAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask me again'**
  String get actionDontAskAgain;

  /// No description provided for @confirmBeforeLeavingEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm before leaving a shared event'**
  String get confirmBeforeLeavingEventLabel;

  /// No description provided for @confirmBeforeLeavingEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a confirmation dialog when you leave an event someone else invited you to'**
  String get confirmBeforeLeavingEventSubtitle;

  /// No description provided for @eventFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get eventFormEditTitle;

  /// No description provided for @eventFormNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get eventFormNewTitle;

  /// No description provided for @sharedWithYou.
  ///
  /// In en, this message translates to:
  /// **'Shared with you'**
  String get sharedWithYou;

  /// No description provided for @sharedByOwner.
  ///
  /// In en, this message translates to:
  /// **'Shared by {ownerName}'**
  String sharedByOwner(String ownerName);

  /// No description provided for @tooltipSharedEvent.
  ///
  /// In en, this message translates to:
  /// **'Shared by {ownerName}'**
  String tooltipSharedEvent(String ownerName);

  /// No description provided for @alsoSharedWithHeader.
  ///
  /// In en, this message translates to:
  /// **'Also shared with'**
  String get alsoSharedWithHeader;

  /// No description provided for @pendingInviteBadge.
  ///
  /// In en, this message translates to:
  /// **'Invite pending'**
  String get pendingInviteBadge;

  /// No description provided for @pendingInviteScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Event invite'**
  String get pendingInviteScreenTitle;

  /// No description provided for @pendingInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'{ownerName} invited you to this event.'**
  String pendingInviteMessage(String ownerName);

  /// No description provided for @actionAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get actionAccept;

  /// No description provided for @actionDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get actionDecline;

  /// No description provided for @inviteRespondFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t respond to the invite: {error}'**
  String inviteRespondFailed(String error);

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @validatorTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get validatorTitleRequired;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @fieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fieldLocation;

  /// No description provided for @fieldDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get fieldDay;

  /// No description provided for @actionNoSpecificTime.
  ///
  /// In en, this message translates to:
  /// **'No specific time'**
  String get actionNoSpecificTime;

  /// No description provided for @actionAddATime.
  ///
  /// In en, this message translates to:
  /// **'Add a time'**
  String get actionAddATime;

  /// No description provided for @labelStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get labelStart;

  /// No description provided for @labelEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get labelEnd;

  /// No description provided for @fieldRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get fieldRepeat;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @repeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get repeatYearly;

  /// No description provided for @everyWord.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get everyWord;

  /// No description provided for @repeatUnitDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{day} other{days}}'**
  String repeatUnitDay(num count);

  /// No description provided for @repeatUnitWeek.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{week} other{weeks}}'**
  String repeatUnitWeek(num count);

  /// No description provided for @repeatUnitMonth.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{month} other{months}}'**
  String repeatUnitMonth(num count);

  /// No description provided for @repeatUnitYear.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{year} other{years}}'**
  String repeatUnitYear(num count);

  /// No description provided for @endsWord.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get endsWord;

  /// No description provided for @repeatEndNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get repeatEndNever;

  /// No description provided for @repeatEndOnDate.
  ///
  /// In en, this message translates to:
  /// **'On date'**
  String get repeatEndOnDate;

  /// No description provided for @repeatEndOnDateWithValue.
  ///
  /// In en, this message translates to:
  /// **'On date ({date})'**
  String repeatEndOnDateWithValue(String date);

  /// No description provided for @repeatEndAfterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{After {count} occurrence} other{After {count} occurrences}}'**
  String repeatEndAfterCount(num count);

  /// No description provided for @occurrencesLabel.
  ///
  /// In en, this message translates to:
  /// **'Occurrences:'**
  String get occurrencesLabel;

  /// No description provided for @seriesChangeNotice.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to the entire series.'**
  String get seriesChangeNotice;

  /// No description provided for @remindersHeader.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersHeader;

  /// No description provided for @actionCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get actionCustom;

  /// No description provided for @reminderAtStartTime.
  ///
  /// In en, this message translates to:
  /// **'At start time'**
  String get reminderAtStartTime;

  /// No description provided for @reminderMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String reminderMinutesBefore(num minutes);

  /// No description provided for @reminderDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{1 day before} other{{days} days before}}'**
  String reminderDaysBefore(num days);

  /// No description provided for @reminderHoursBefore.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, one{1 hour before} other{{hours} hours before}}'**
  String reminderHoursBefore(num hours);

  /// No description provided for @customReminderDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remind me before'**
  String get customReminderDialogTitle;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get unitMinutes;

  /// No description provided for @unitHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get unitHours;

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get unitDays;

  /// No description provided for @actionSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get actionSaveChanges;

  /// No description provided for @actionCreateEvent.
  ///
  /// In en, this message translates to:
  /// **'Create event'**
  String get actionCreateEvent;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsCategoryGeneral;

  /// No description provided for @settingsCategoryGeneralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, language, and startup'**
  String get settingsCategoryGeneralSubtitle;

  /// No description provided for @settingsCategoryCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get settingsCategoryCalendar;

  /// No description provided for @settingsCategoryCalendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which day the week starts on'**
  String get settingsCategoryCalendarSubtitle;

  /// No description provided for @settingsCategoryVoiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get settingsCategoryVoiceInput;

  /// No description provided for @settingsCategoryVoiceInputSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone used by the assistant'**
  String get settingsCategoryVoiceInputSubtitle;

  /// No description provided for @settingsCategoryReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsCategoryReminders;

  /// No description provided for @settingsCategoryRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification channel and sounds'**
  String get settingsCategoryRemindersSubtitle;

  /// No description provided for @settingsCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsCategoryAccount;

  /// No description provided for @settingsCategoryAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Email, username, password, and account deletion'**
  String get settingsCategoryAccountSubtitle;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get sectionCalendar;

  /// No description provided for @sectionReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get sectionReminders;

  /// No description provided for @sectionStartup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get sectionStartup;

  /// No description provided for @launchAtLogin.
  ///
  /// In en, this message translates to:
  /// **'Launch at login'**
  String get launchAtLogin;

  /// No description provided for @launchAtLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start Calendar App minimized to the tray when you sign in to Windows, so reminders keep firing'**
  String get launchAtLoginSubtitle;

  /// No description provided for @sectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get sectionAccount;

  /// No description provided for @changeUsernameDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Change username'**
  String get changeUsernameDialogTitle;

  /// No description provided for @changeEmailDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmailDialogTitle;

  /// No description provided for @changePasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordDialogTitle;

  /// No description provided for @fieldNewUsername.
  ///
  /// In en, this message translates to:
  /// **'New username'**
  String get fieldNewUsername;

  /// No description provided for @fieldNewEmail.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get fieldNewEmail;

  /// No description provided for @fieldCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get fieldCurrentPassword;

  /// No description provided for @verifyNewEmailDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your new email'**
  String get verifyNewEmailDialogTitle;

  /// No description provided for @verifyNewEmailMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {email}'**
  String verifyNewEmailMessage(String email);

  /// No description provided for @usernameChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Username changed'**
  String get usernameChangedMessage;

  /// No description provided for @passwordChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChangedMessage;

  /// No description provided for @emailChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Email changed'**
  String get emailChangedMessage;

  /// No description provided for @sectionDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get sectionDangerZone;

  /// No description provided for @actionDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get actionDeleteAccount;

  /// No description provided for @deleteAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountDialogTitle;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account. Events, groups, and friendships that are only yours are removed entirely; anything shared with other people (like an event they accepted) is kept, with your identity anonymized. This can\'t be undone. Enter your password to confirm.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountConfirmButton;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @weekStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Week starts on {day}'**
  String weekStartsOn(String day);

  /// No description provided for @enableReminderNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable reminder notifications'**
  String get enableReminderNotifications;

  /// No description provided for @inAppPopup.
  ///
  /// In en, this message translates to:
  /// **'In-app popup'**
  String get inAppPopup;

  /// No description provided for @inAppPopupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A small window from Calendar App itself'**
  String get inAppPopupSubtitle;

  /// No description provided for @windowsNotification.
  ///
  /// In en, this message translates to:
  /// **'Windows notification'**
  String get windowsNotification;

  /// No description provided for @windowsNotificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The OS notification, matches other apps'**
  String get windowsNotificationSubtitle;

  /// No description provided for @popupPosition.
  ///
  /// In en, this message translates to:
  /// **'Popup position'**
  String get popupPosition;

  /// No description provided for @popupDuration.
  ///
  /// In en, this message translates to:
  /// **'Popup duration'**
  String get popupDuration;

  /// No description provided for @soundSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundSectionLabel;

  /// No description provided for @soundFileFormatsHint.
  ///
  /// In en, this message translates to:
  /// **'mp3, wav, ogg, m4a...'**
  String get soundFileFormatsHint;

  /// No description provided for @noFileChosen.
  ///
  /// In en, this message translates to:
  /// **'No file chosen'**
  String get noFileChosen;

  /// No description provided for @actionChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file...'**
  String get actionChooseFile;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @tooltipPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get tooltipPreview;

  /// No description provided for @actionSendTestReminder.
  ///
  /// In en, this message translates to:
  /// **'Send a test reminder'**
  String get actionSendTestReminder;

  /// No description provided for @dialogChooseReminderSound.
  ///
  /// In en, this message translates to:
  /// **'Choose a reminder sound'**
  String get dialogChooseReminderSound;

  /// No description provided for @testReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Test reminder'**
  String get testReminderTitle;

  /// No description provided for @testReminderBody.
  ///
  /// In en, this message translates to:
  /// **'This is what your reminders will look like.'**
  String get testReminderBody;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match system'**
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

  /// No description provided for @weekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySunday;

  /// No description provided for @soundNone.
  ///
  /// In en, this message translates to:
  /// **'No sound'**
  String get soundNone;

  /// No description provided for @soundClick.
  ///
  /// In en, this message translates to:
  /// **'Click'**
  String get soundClick;

  /// No description provided for @soundAlert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get soundAlert;

  /// No description provided for @soundCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom sound file'**
  String get soundCustom;

  /// No description provided for @cornerTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Top left'**
  String get cornerTopLeft;

  /// No description provided for @cornerTopRight.
  ///
  /// In en, this message translates to:
  /// **'Top right'**
  String get cornerTopRight;

  /// No description provided for @cornerBottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom left'**
  String get cornerBottomLeft;

  /// No description provided for @cornerBottomRight.
  ///
  /// In en, this message translates to:
  /// **'Bottom right'**
  String get cornerBottomRight;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @socialTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends & Groups'**
  String get socialTitle;

  /// No description provided for @tabFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get tabFriends;

  /// No description provided for @tabRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get tabRequests;

  /// No description provided for @tabGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get tabGroups;

  /// No description provided for @tabInvites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get tabInvites;

  /// No description provided for @searchByUsername.
  ///
  /// In en, this message translates to:
  /// **'Search by username'**
  String get searchByUsername;

  /// No description provided for @noFriendsYetHint.
  ///
  /// In en, this message translates to:
  /// **'No friends yet — search a username above'**
  String get noFriendsYetHint;

  /// No description provided for @tooltipRemoveFriend.
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get tooltipRemoveFriend;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @relationshipFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get relationshipFriends;

  /// No description provided for @relationshipRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get relationshipRequested;

  /// No description provided for @relationshipCheckRequestsTab.
  ///
  /// In en, this message translates to:
  /// **'Check Requests tab'**
  String get relationshipCheckRequestsTab;

  /// No description provided for @sectionIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get sectionIncoming;

  /// No description provided for @noIncomingRequests.
  ///
  /// In en, this message translates to:
  /// **'No incoming requests'**
  String get noIncomingRequests;

  /// No description provided for @sectionSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sectionSent;

  /// No description provided for @noPendingSentRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending sent requests'**
  String get noPendingSentRequests;

  /// No description provided for @sectionMyGroups.
  ///
  /// In en, this message translates to:
  /// **'My groups'**
  String get sectionMyGroups;

  /// No description provided for @sectionGroupsImIn.
  ///
  /// In en, this message translates to:
  /// **'Groups I\'m in'**
  String get sectionGroupsImIn;

  /// No description provided for @noGroupsYetHint.
  ///
  /// In en, this message translates to:
  /// **'No groups yet — create one below'**
  String get noGroupsYetHint;

  /// No description provided for @notInAnyGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in any groups'**
  String get notInAnyGroupsHint;

  /// No description provided for @groupOwnedBy.
  ///
  /// In en, this message translates to:
  /// **'Owned by {name}'**
  String groupOwnedBy(String name);

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String memberCount(num count);

  /// No description provided for @actionAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get actionAddMember;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @dialogAddFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a friend'**
  String get dialogAddFriendTitle;

  /// No description provided for @addFriendsFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Add some friends first'**
  String get addFriendsFirstHint;

  /// No description provided for @dialogNewGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get dialogNewGroupTitle;

  /// No description provided for @dialogRenameGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get dialogRenameGroupTitle;

  /// No description provided for @fieldGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get fieldGroupName;

  /// No description provided for @noPendingEventInvites.
  ///
  /// In en, this message translates to:
  /// **'No pending event invites'**
  String get noPendingEventInvites;

  /// No description provided for @inviteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From {name} · {when}'**
  String inviteSubtitle(String name, String when);

  /// No description provided for @noSpecificTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'No specific time'**
  String get noSpecificTimeLabel;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get statusPending;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'accepted'**
  String get statusAccepted;

  /// No description provided for @statusDeclined.
  ///
  /// In en, this message translates to:
  /// **'declined'**
  String get statusDeclined;

  /// No description provided for @peopleHeader.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get peopleHeader;

  /// No description provided for @noOneElseInvited.
  ///
  /// In en, this message translates to:
  /// **'No one else invited yet'**
  String get noOneElseInvited;

  /// No description provided for @tooltipRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tooltipRemove;

  /// No description provided for @actionAddPeople.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get actionAddPeople;

  /// No description provided for @actionAddGroups.
  ///
  /// In en, this message translates to:
  /// **'Add groups'**
  String get actionAddGroups;

  /// No description provided for @dialogAddPeopleTitle.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get dialogAddPeopleTitle;

  /// No description provided for @dialogAddGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add groups'**
  String get dialogAddGroupsTitle;

  /// No description provided for @noGroupsToPickHint.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any groups yet'**
  String get noGroupsToPickHint;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @noResultsForSearch.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noResultsForSearch;

  /// No description provided for @willBeSentOnSave.
  ///
  /// In en, this message translates to:
  /// **'Will be sent when you save'**
  String get willBeSentOnSave;

  /// No description provided for @inviteApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Event saved, but invites couldn\'t be sent: {error}'**
  String inviteApplyFailed(String error);

  /// No description provided for @dialogChooseFileToAttach.
  ///
  /// In en, this message translates to:
  /// **'Choose a file to attach'**
  String get dialogChooseFileToAttach;

  /// No description provided for @attachmentsHeader.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachmentsHeader;

  /// No description provided for @actionAddFile.
  ///
  /// In en, this message translates to:
  /// **'Add file'**
  String get actionAddFile;

  /// No description provided for @noAttachmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No attachments yet'**
  String get noAttachmentsYet;

  /// No description provided for @tooltipDeleteAttachment.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tooltipDeleteAttachment;

  /// No description provided for @failedToLoadGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String failedToLoadGeneric(String error);

  /// No description provided for @failedToLoadFriends.
  ///
  /// In en, this message translates to:
  /// **'Failed to load friends: {error}'**
  String failedToLoadFriends(String error);

  /// No description provided for @failedToLoadGroups.
  ///
  /// In en, this message translates to:
  /// **'Failed to load groups: {error}'**
  String failedToLoadGroups(String error);

  /// No description provided for @failedToLoadInvites.
  ///
  /// In en, this message translates to:
  /// **'Failed to load invites: {error}'**
  String failedToLoadInvites(String error);

  /// No description provided for @failedToLoadAttachments.
  ///
  /// In en, this message translates to:
  /// **'Failed to load attachments: {error}'**
  String failedToLoadAttachments(String error);

  /// No description provided for @editRecurringEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring event'**
  String get editRecurringEventTitle;

  /// No description provided for @deleteRecurringEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recurring event'**
  String get deleteRecurringEventTitle;

  /// No description provided for @scopeThisEvent.
  ///
  /// In en, this message translates to:
  /// **'This event'**
  String get scopeThisEvent;

  /// No description provided for @scopeAllEvents.
  ///
  /// In en, this message translates to:
  /// **'All events'**
  String get scopeAllEvents;

  /// No description provided for @repeatMonthlyByDay.
  ///
  /// In en, this message translates to:
  /// **'Monthly on day {day}'**
  String repeatMonthlyByDay(int day);

  /// No description provided for @repeatMonthlyByWeekday.
  ///
  /// In en, this message translates to:
  /// **'Monthly on the {ordinal} {weekday}'**
  String repeatMonthlyByWeekday(String ordinal, String weekday);

  /// No description provided for @ordinalFirst.
  ///
  /// In en, this message translates to:
  /// **'first'**
  String get ordinalFirst;

  /// No description provided for @ordinalSecond.
  ///
  /// In en, this message translates to:
  /// **'second'**
  String get ordinalSecond;

  /// No description provided for @ordinalThird.
  ///
  /// In en, this message translates to:
  /// **'third'**
  String get ordinalThird;

  /// No description provided for @ordinalFourth.
  ///
  /// In en, this message translates to:
  /// **'fourth'**
  String get ordinalFourth;

  /// No description provided for @ordinalLast.
  ///
  /// In en, this message translates to:
  /// **'last'**
  String get ordinalLast;

  /// No description provided for @sectionVoiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get sectionVoiceInput;

  /// No description provided for @fieldMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get fieldMicrophone;

  /// No description provided for @microphoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If voice commands aren\'t being picked up, pick the microphone you actually speak into — the system default isn\'t always the right one on machines with several.'**
  String get microphoneSubtitle;

  /// No description provided for @microphoneSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get microphoneSystemDefault;

  /// No description provided for @microphoneListError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t list microphones.'**
  String get microphoneListError;

  /// No description provided for @actionTestMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Test microphone'**
  String get actionTestMicrophone;

  /// No description provided for @actionStopMicTest.
  ///
  /// In en, this message translates to:
  /// **'Stop test'**
  String get actionStopMicTest;

  /// No description provided for @tooltipAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get tooltipAssistant;

  /// No description provided for @tooltipAddEvent.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get tooltipAddEvent;

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistantTitle;

  /// No description provided for @assistantInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask me to schedule, find, or change something...'**
  String get assistantInputHint;

  /// No description provided for @assistantRecordingHint.
  ///
  /// In en, this message translates to:
  /// **'Listening... tap the mic again to stop'**
  String get assistantRecordingHint;

  /// No description provided for @assistantTranscribingHint.
  ///
  /// In en, this message translates to:
  /// **'Transcribing...'**
  String get assistantTranscribingHint;

  /// No description provided for @assistantEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Ask me to schedule, find, or change something on your calendar.'**
  String get assistantEmptyState;

  /// No description provided for @assistantConfirmDeleteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Delete this event?} other{Delete these {count} events?}}'**
  String assistantConfirmDeleteCount(num count);

  /// No description provided for @assistantDeletedConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{title}\".'**
  String assistantDeletedConfirmation(String title);

  /// No description provided for @assistantErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String assistantErrorGeneric(String error);

  /// No description provided for @reminderStartingNow.
  ///
  /// In en, this message translates to:
  /// **'{title} is starting now'**
  String reminderStartingNow(String title);

  /// No description provided for @reminderWithLabel.
  ///
  /// In en, this message translates to:
  /// **'{title} — {label}'**
  String reminderWithLabel(String title, String label);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
