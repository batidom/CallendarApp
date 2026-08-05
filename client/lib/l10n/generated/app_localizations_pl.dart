// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get actionCancel => 'Anuluj';

  @override
  String get actionSave => 'Zapisz';

  @override
  String get actionDelete => 'Usuń';

  @override
  String get actionAdd => 'Dodaj';

  @override
  String get actionGo => 'Przejdź';

  @override
  String get loginCreateAccount => 'Utwórz konto';

  @override
  String get loginSignIn => 'Zaloguj się';

  @override
  String get fieldEmail => 'E-mail';

  @override
  String get validatorEmailInvalid => 'Podaj prawidłowy adres e-mail';

  @override
  String get fieldName => 'Imię';

  @override
  String get validatorNameRequired => 'Imię jest wymagane';

  @override
  String get fieldSurnameOptional => 'Nazwisko (opcjonalnie)';

  @override
  String get fieldUsername => 'Nazwa użytkownika';

  @override
  String get usernameHelperText => 'Po tym znajdą Cię znajomi';

  @override
  String get validatorUsernameTooShort => 'Minimum 3 znaki';

  @override
  String get validatorUsernameFormat => 'Tylko litery, cyfry i podkreślenia';

  @override
  String get fieldPassword => 'Hasło';

  @override
  String get validatorPasswordTooShort => 'Minimum 8 znaków';

  @override
  String get loginRegisterButton => 'Zarejestruj się';

  @override
  String get loginLoginButton => 'Zaloguj';

  @override
  String get loginToggleToSignIn => 'Masz już konto? Zaloguj się';

  @override
  String get loginToggleToRegister => 'Potrzebujesz konta? Zarejestruj się';

  @override
  String get loginKeepMeSignedIn => 'Pozostań zalogowany/a';

  @override
  String get loginKeepMeSignedInSubtitle =>
      'Wyłącz na współdzielonym komputerze, aby kolejna osoba nie zobaczyła Twojego kalendarza';

  @override
  String get verifyEmailTitle => 'Zweryfikuj adres e-mail';

  @override
  String verifyEmailSubtitle(String email) {
    return 'Wysłaliśmy 6-cyfrowy kod na adres $email. Wpisz go poniżej, aby dokończyć zakładanie konta.';
  }

  @override
  String get fieldVerificationCode => 'Kod weryfikacyjny';

  @override
  String get validatorCodeInvalid => 'Wpisz 6-cyfrowy kod';

  @override
  String get verifyEmailButton => 'Zweryfikuj';

  @override
  String get verifyEmailResend => 'Wyślij kod ponownie';

  @override
  String get verifyEmailResendSent =>
      'Kod wysłany — sprawdź skrzynkę odbiorczą';

  @override
  String get verifyEmailBackToSignIn => 'Wróć do logowania';

  @override
  String get loginForgotPassword => 'Nie pamiętasz hasła?';

  @override
  String get forgotPasswordTitle => 'Zresetuj hasło';

  @override
  String get forgotPasswordSubtitle =>
      'Podaj adres e-mail konta, a wyślemy Ci kod resetujący.';

  @override
  String get forgotPasswordSendButton => 'Wyślij kod resetujący';

  @override
  String get forgotPasswordBackToSignIn => 'Wróć do logowania';

  @override
  String get resetPasswordTitle => 'Wpisz kod resetujący';

  @override
  String resetPasswordSubtitle(String email) {
    return 'Wysłaliśmy 6-cyfrowy kod na adres $email. Wpisz go poniżej razem z nowym hasłem.';
  }

  @override
  String get fieldNewPassword => 'Nowe hasło';

  @override
  String get resetPasswordButton => 'Zresetuj hasło';

  @override
  String get calendarTitle => 'Kalendarz';

  @override
  String eventsLoadError(String error) {
    return 'Nie udało się wczytać wydarzeń: $error';
  }

  @override
  String get tooltipSettings => 'Ustawienia';

  @override
  String get tooltipSignOut => 'Wyloguj się';

  @override
  String get tooltipHideEsc => 'Ukryj (Esc)';

  @override
  String get tooltipNotifications => 'Powiadomienia';

  @override
  String get noNotificationsYet => 'Brak powiadomień';

  @override
  String get actionViewAllNotifications => 'Zobacz wszystkie powiadomienia';

  @override
  String get notificationsScreenTitle => 'Powiadomienia';

  @override
  String get tooltipFriendsGroups => 'Znajomi i grupy';

  @override
  String get goToMonthTitle => 'Przejdź do miesiąca';

  @override
  String get noEventsOnThisDay => 'Brak wydarzeń tego dnia';

  @override
  String get anytime => 'O dowolnej porze';

  @override
  String get somedayHeader => 'Kiedyś...';

  @override
  String get addSomedayHint => 'Dodaj coś na kiedyś...';

  @override
  String get dragIdeasHint =>
      'Przeciągnij pomysł na dzień, gdy będziesz gotowy(-a)';

  @override
  String get allDay => 'Cały dzień';

  @override
  String durationTbd(String time) {
    return '$time (czas trwania nieznany)';
  }

  @override
  String get tooltipHasDescription => 'Ma opis';

  @override
  String get tooltipRepeats => 'Powtarza się — edytuj, aby zmienić serię';

  @override
  String get tooltipNotSynced => 'Jeszcze niezsynchronizowane';

  @override
  String notificationFriendRequestReceived(String name) {
    return '$name wysłał(a) Ci zaproszenie do znajomych';
  }

  @override
  String notificationFriendRequestAccepted(String name) {
    return '$name zaakceptował(a) Twoje zaproszenie do znajomych';
  }

  @override
  String notificationLeftEvent(String name, String event) {
    return '$name opuścił(a) „$event”';
  }

  @override
  String notificationInviteAccepted(String name, String event) {
    return '$name zaakceptował(a) zaproszenie do „$event”';
  }

  @override
  String notificationInviteDeclined(String name, String event) {
    return '$name odrzucił(a) zaproszenie do „$event”';
  }

  @override
  String notificationDateChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  ) {
    return '$name zmienił(a) datę „$event” z $oldValue na $newValue';
  }

  @override
  String notificationTimeChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  ) {
    return '$name zmienił(a) godzinę „$event” z $oldValue na $newValue';
  }

  @override
  String notificationLocationChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  ) {
    return '$name zmienił(a) miejsce „$event” z $oldValue na $newValue';
  }

  @override
  String notificationDescriptionChanged(
    String name,
    String event,
    String oldValue,
    String newValue,
  ) {
    return '$name zmienił(a) opis „$event” z „$oldValue” na „$newValue”';
  }

  @override
  String get notificationEmptyValue => 'brak';

  @override
  String get actionLeaveEvent => 'Opuść wydarzenie';

  @override
  String get leaveEventDialogTitle => 'Opuścić to wydarzenie?';

  @override
  String get leaveEventDialogMessage =>
      'Przestaniesz je widzieć w swoim kalendarzu, a organizator i pozostali uczestnicy zostaną powiadomieni, że je opuściłeś(-aś).';

  @override
  String get sectionConfirmations => 'Potwierdzenia';

  @override
  String get sectionOtherNotifications => 'Inne powiadomienia';

  @override
  String get otherNotificationsSubtitle =>
      'Zaproszenia do znajomych, zaproszenia na wydarzenia oraz zmiany w udostępnionych wydarzeniach';

  @override
  String get notificationSoundEnabledLabel => 'Odtwarzaj dźwięk';

  @override
  String get notificationVolumeLabel => 'Głośność';

  @override
  String get reminderVolumeLabel => 'Głośność';

  @override
  String get actionDontAskAgain => 'Nie pytaj mnie ponownie';

  @override
  String get confirmBeforeLeavingEventLabel =>
      'Potwierdź przed opuszczeniem udostępnionego wydarzenia';

  @override
  String get confirmBeforeLeavingEventSubtitle =>
      'Pokazuj okno potwierdzenia przy opuszczaniu wydarzenia, na które zostałeś(-aś) zaproszony(-a)';

  @override
  String get eventFormEditTitle => 'Edytuj wydarzenie';

  @override
  String get eventFormNewTitle => 'Nowe wydarzenie';

  @override
  String get sharedWithYou => 'Udostępnione Tobie';

  @override
  String sharedByOwner(String ownerName) {
    return 'Udostępnione przez $ownerName';
  }

  @override
  String tooltipSharedEvent(String ownerName) {
    return 'Udostępnione przez $ownerName';
  }

  @override
  String get alsoSharedWithHeader => 'Udostępniono również';

  @override
  String get pendingInviteBadge => 'Oczekujące zaproszenie';

  @override
  String get pendingInviteScreenTitle => 'Zaproszenie na wydarzenie';

  @override
  String pendingInviteMessage(String ownerName) {
    return '$ownerName zaprosił(a) Cię na to wydarzenie.';
  }

  @override
  String get actionAccept => 'Akceptuj';

  @override
  String get actionDecline => 'Odrzuć';

  @override
  String inviteRespondFailed(String error) {
    return 'Nie udało się odpowiedzieć na zaproszenie: $error';
  }

  @override
  String get fieldTitle => 'Tytuł';

  @override
  String get validatorTitleRequired => 'Tytuł jest wymagany';

  @override
  String get fieldDescription => 'Opis';

  @override
  String get fieldLocation => 'Lokalizacja';

  @override
  String get fieldDay => 'Dzień';

  @override
  String get actionNoSpecificTime => 'Bez konkretnej godziny';

  @override
  String get actionAddATime => 'Dodaj godzinę';

  @override
  String get labelStart => 'Start';

  @override
  String get labelEnd => 'Koniec';

  @override
  String get fieldRepeat => 'Powtarzanie';

  @override
  String get repeatNone => 'Nie powtarza się';

  @override
  String get repeatDaily => 'Codziennie';

  @override
  String get repeatWeekly => 'Co tydzień';

  @override
  String get repeatMonthly => 'Co miesiąc';

  @override
  String get repeatYearly => 'Co rok';

  @override
  String get everyWord => 'Co';

  @override
  String repeatUnitDay(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dni',
      many: 'dni',
      few: 'dni',
      one: 'dzień',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitWeek(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tygodni',
      many: 'tygodni',
      few: 'tygodnie',
      one: 'tydzień',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitMonth(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'miesięcy',
      many: 'miesięcy',
      few: 'miesiące',
      one: 'miesiąc',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitYear(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'lat',
      many: 'lat',
      few: 'lata',
      one: 'rok',
    );
    return '$_temp0';
  }

  @override
  String get endsWord => 'Zakończenie';

  @override
  String get repeatEndNever => 'Nigdy';

  @override
  String get repeatEndOnDate => 'W dniu';

  @override
  String repeatEndOnDateWithValue(String date) {
    return 'W dniu ($date)';
  }

  @override
  String repeatEndAfterCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Po $count wystąpieniach',
      many: 'Po $count wystąpieniach',
      few: 'Po $count wystąpieniach',
      one: 'Po $count wystąpieniu',
    );
    return '$_temp0';
  }

  @override
  String get occurrencesLabel => 'Liczba wystąpień:';

  @override
  String get seriesChangeNotice => 'Zmiany dotyczą całej serii.';

  @override
  String get remindersHeader => 'Przypomnienia';

  @override
  String get actionCustom => 'Własne';

  @override
  String get reminderAtStartTime => 'W momencie rozpoczęcia';

  @override
  String reminderMinutesBefore(num minutes) {
    return '$minutes min przed';
  }

  @override
  String reminderDaysBefore(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dni przed',
      many: '$days dni przed',
      few: '$days dni przed',
      one: '1 dzień przed',
    );
    return '$_temp0';
  }

  @override
  String reminderHoursBefore(num hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours godzin przed',
      many: '$hours godzin przed',
      few: '$hours godziny przed',
      one: '1 godzinę przed',
    );
    return '$_temp0';
  }

  @override
  String get customReminderDialogTitle => 'Przypomnij przed';

  @override
  String get fieldAmount => 'Ilość';

  @override
  String get unitMinutes => 'Minuty';

  @override
  String get unitHours => 'Godziny';

  @override
  String get unitDays => 'Dni';

  @override
  String get actionSaveChanges => 'Zapisz zmiany';

  @override
  String get actionCreateEvent => 'Utwórz wydarzenie';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsCategoryGeneral => 'Ogólne';

  @override
  String get settingsCategoryGeneralSubtitle => 'Motyw, język i uruchamianie';

  @override
  String get settingsCategoryCalendar => 'Kalendarz';

  @override
  String get settingsCategoryCalendarSubtitle =>
      'Od którego dnia zaczyna się tydzień';

  @override
  String get settingsCategoryVoiceInput => 'Wejście głosowe';

  @override
  String get settingsCategoryVoiceInputSubtitle =>
      'Mikrofon używany przez asystenta';

  @override
  String get settingsCategoryReminders => 'Przypomnienia';

  @override
  String get settingsCategoryRemindersSubtitle => 'Kanał powiadomień i dźwięki';

  @override
  String get settingsCategoryAccount => 'Konto';

  @override
  String get settingsCategoryAccountSubtitle =>
      'E-mail, nazwa użytkownika, hasło i usunięcie konta';

  @override
  String get sectionAppearance => 'Wygląd';

  @override
  String get sectionCalendar => 'Kalendarz';

  @override
  String get sectionReminders => 'Przypomnienia';

  @override
  String get sectionStartup => 'Uruchamianie';

  @override
  String get launchAtLogin => 'Uruchamiaj przy logowaniu';

  @override
  String get launchAtLoginSubtitle =>
      'Uruchamiaj Calendar App zminimalizowaną w zasobniku systemowym po zalogowaniu do Windows, aby przypomnienia nadal działały';

  @override
  String get sectionAccount => 'Konto';

  @override
  String get changeUsernameDialogTitle => 'Zmień nazwę użytkownika';

  @override
  String get changeEmailDialogTitle => 'Zmień adres e-mail';

  @override
  String get changePasswordDialogTitle => 'Zmień hasło';

  @override
  String get fieldNewUsername => 'Nowa nazwa użytkownika';

  @override
  String get fieldNewEmail => 'Nowy adres e-mail';

  @override
  String get fieldCurrentPassword => 'Obecne hasło';

  @override
  String get verifyNewEmailDialogTitle => 'Zweryfikuj nowy adres e-mail';

  @override
  String verifyNewEmailMessage(String email) {
    return 'Wprowadź kod wysłany na $email';
  }

  @override
  String get usernameChangedMessage => 'Nazwa użytkownika zmieniona';

  @override
  String get passwordChangedMessage => 'Hasło zmienione';

  @override
  String get emailChangedMessage => 'Adres e-mail zmieniony';

  @override
  String get sectionDangerZone => 'Strefa niebezpieczna';

  @override
  String get actionDeleteAccount => 'Usuń konto';

  @override
  String get deleteAccountDialogTitle => 'Usunąć konto?';

  @override
  String get deleteAccountWarning =>
      'To trwale usuwa Twoje konto. Wydarzenia, grupy i znajomości należące wyłącznie do Ciebie zostaną całkowicie usunięte; wszystko, czym dzielisz się z innymi osobami (np. wydarzenie, które ktoś zaakceptował), zostanie zachowane, a Twoja tożsamość zostanie zanonimizowana. Tej operacji nie można cofnąć. Wpisz hasło, aby potwierdzić.';

  @override
  String get deleteAccountConfirmButton => 'Usuń moje konto';

  @override
  String get sectionLanguage => 'Język';

  @override
  String weekStartsOn(String day) {
    return 'Tydzień zaczyna się od: $day';
  }

  @override
  String get enableReminderNotifications =>
      'Włącz powiadomienia o przypomnieniach';

  @override
  String get inAppPopup => 'Wyskakujące okienko w aplikacji';

  @override
  String get inAppPopupSubtitle => 'Małe okno samej aplikacji Calendar App';

  @override
  String get windowsNotification => 'Powiadomienie systemowe';

  @override
  String get windowsNotificationSubtitle =>
      'Powiadomienie systemu operacyjnego, tak jak w innych aplikacjach';

  @override
  String get popupPosition => 'Pozycja okienka';

  @override
  String get popupDuration => 'Czas wyświetlania okienka';

  @override
  String get soundSectionLabel => 'Dźwięk';

  @override
  String get soundFileFormatsHint => 'mp3, wav, ogg, m4a...';

  @override
  String get noFileChosen => 'Nie wybrano pliku';

  @override
  String get actionChooseFile => 'Wybierz plik...';

  @override
  String get actionChange => 'Zmień';

  @override
  String get tooltipPreview => 'Odsłuchaj';

  @override
  String get actionSendTestReminder => 'Wyślij testowe przypomnienie';

  @override
  String get dialogChooseReminderSound => 'Wybierz dźwięk przypomnienia';

  @override
  String get testReminderTitle => 'Testowe przypomnienie';

  @override
  String get testReminderBody => 'Tak będą wyglądać Twoje przypomnienia.';

  @override
  String get themeSystem => 'Zgodnie z systemem';

  @override
  String get themeLight => 'Jasny';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get weekdayMonday => 'Poniedziałek';

  @override
  String get weekdayTuesday => 'Wtorek';

  @override
  String get weekdayWednesday => 'Środa';

  @override
  String get weekdayThursday => 'Czwartek';

  @override
  String get weekdayFriday => 'Piątek';

  @override
  String get weekdaySaturday => 'Sobota';

  @override
  String get weekdaySunday => 'Niedziela';

  @override
  String get soundNone => 'Brak dźwięku';

  @override
  String get soundClick => 'Kliknięcie';

  @override
  String get soundAlert => 'Alarm';

  @override
  String get soundCustom => 'Własny plik dźwiękowy';

  @override
  String get cornerTopLeft => 'Lewy górny róg';

  @override
  String get cornerTopRight => 'Prawy górny róg';

  @override
  String get cornerBottomLeft => 'Lewy dolny róg';

  @override
  String get cornerBottomRight => 'Prawy dolny róg';

  @override
  String get languageSystemDefault => 'Domyślny systemowy';

  @override
  String get socialTitle => 'Znajomi i grupy';

  @override
  String get tabFriends => 'Znajomi';

  @override
  String get tabRequests => 'Zaproszenia';

  @override
  String get tabGroups => 'Grupy';

  @override
  String get tabInvites => 'Wydarzenia';

  @override
  String get searchByUsername => 'Szukaj po nazwie użytkownika';

  @override
  String get noFriendsYetHint =>
      'Nie masz jeszcze znajomych — wyszukaj nazwę użytkownika powyżej';

  @override
  String get tooltipRemoveFriend => 'Usuń znajomego';

  @override
  String get noUsersFound => 'Nie znaleziono użytkowników';

  @override
  String get relationshipFriends => 'Znajomi';

  @override
  String get relationshipRequested => 'Wysłano zaproszenie';

  @override
  String get relationshipCheckRequestsTab => 'Sprawdź zakładkę Zaproszenia';

  @override
  String get sectionIncoming => 'Otrzymane';

  @override
  String get noIncomingRequests => 'Brak otrzymanych zaproszeń';

  @override
  String get sectionSent => 'Wysłane';

  @override
  String get noPendingSentRequests => 'Brak oczekujących wysłanych zaproszeń';

  @override
  String get sectionMyGroups => 'Moje grupy';

  @override
  String get sectionGroupsImIn => 'Grupy, do których należę';

  @override
  String get noGroupsYetHint => 'Nie masz jeszcze grup — utwórz jedną poniżej';

  @override
  String get notInAnyGroupsHint => 'Nie należysz do żadnej grupy';

  @override
  String groupOwnedBy(String name) {
    return 'Właściciel: $name';
  }

  @override
  String memberCount(num count) {
    return 'Uczestnicy: $count';
  }

  @override
  String get actionAddMember => 'Dodaj uczestnika';

  @override
  String get actionRename => 'Zmień nazwę';

  @override
  String get dialogAddFriendTitle => 'Dodaj znajomego';

  @override
  String get addFriendsFirstHint => 'Najpierw dodaj znajomych';

  @override
  String get dialogNewGroupTitle => 'Nowa grupa';

  @override
  String get dialogRenameGroupTitle => 'Zmień nazwę grupy';

  @override
  String get fieldGroupName => 'Nazwa grupy';

  @override
  String get noPendingEventInvites =>
      'Brak oczekujących zaproszeń na wydarzenia';

  @override
  String inviteSubtitle(String name, String when) {
    return 'Od $name · $when';
  }

  @override
  String get noSpecificTimeLabel => 'Bez konkretnej godziny';

  @override
  String get statusPending => 'oczekujące';

  @override
  String get statusAccepted => 'zaakceptowane';

  @override
  String get statusDeclined => 'odrzucone';

  @override
  String get peopleHeader => 'Osoby';

  @override
  String get noOneElseInvited => 'Nikogo jeszcze nie zaproszono';

  @override
  String get tooltipRemove => 'Usuń';

  @override
  String get actionAddPeople => 'Dodaj osoby';

  @override
  String get actionAddGroups => 'Dodaj grupy';

  @override
  String get dialogAddPeopleTitle => 'Dodaj osoby';

  @override
  String get dialogAddGroupsTitle => 'Dodaj grupy';

  @override
  String get noGroupsToPickHint => 'Nie masz jeszcze żadnych grup';

  @override
  String get searchHint => 'Szukaj';

  @override
  String get noResultsForSearch => 'Brak wyników';

  @override
  String get willBeSentOnSave => 'Zostanie wysłane po zapisaniu';

  @override
  String inviteApplyFailed(String error) {
    return 'Wydarzenie zapisane, ale nie udało się wysłać zaproszeń: $error';
  }

  @override
  String get dialogChooseFileToAttach => 'Wybierz plik do załączenia';

  @override
  String get attachmentsHeader => 'Załączniki';

  @override
  String get actionAddFile => 'Dodaj plik';

  @override
  String get noAttachmentsYet => 'Brak załączników';

  @override
  String get tooltipDeleteAttachment => 'Usuń';

  @override
  String failedToLoadGeneric(String error) {
    return 'Nie udało się wczytać: $error';
  }

  @override
  String failedToLoadFriends(String error) {
    return 'Nie udało się wczytać znajomych: $error';
  }

  @override
  String failedToLoadGroups(String error) {
    return 'Nie udało się wczytać grup: $error';
  }

  @override
  String failedToLoadInvites(String error) {
    return 'Nie udało się wczytać zaproszeń: $error';
  }

  @override
  String failedToLoadAttachments(String error) {
    return 'Nie udało się wczytać załączników: $error';
  }

  @override
  String get editRecurringEventTitle => 'Edytuj cykliczne wydarzenie';

  @override
  String get deleteRecurringEventTitle => 'Usuń cykliczne wydarzenie';

  @override
  String get scopeThisEvent => 'To wydarzenie';

  @override
  String get scopeAllEvents => 'Wszystkie wydarzenia';

  @override
  String repeatMonthlyByDay(int day) {
    return 'Co miesiąc, dnia $day';
  }

  @override
  String repeatMonthlyByWeekday(String ordinal, String weekday) {
    return 'Co miesiąc, w $ordinal $weekday';
  }

  @override
  String get ordinalFirst => 'pierwszy';

  @override
  String get ordinalSecond => 'drugi';

  @override
  String get ordinalThird => 'trzeci';

  @override
  String get ordinalFourth => 'czwarty';

  @override
  String get ordinalLast => 'ostatni';

  @override
  String get sectionVoiceInput => 'Wejście głosowe';

  @override
  String get fieldMicrophone => 'Mikrofon';

  @override
  String get microphoneSubtitle =>
      'Jeśli polecenia głosowe nie są wychwytywane, wybierz mikrofon, do którego rzeczywiście mówisz — domyślny mikrofon systemowy nie zawsze jest właściwy, gdy masz ich kilka.';

  @override
  String get microphoneSystemDefault => 'Domyślny systemowy';

  @override
  String get microphoneListError => 'Nie udało się pobrać listy mikrofonów.';

  @override
  String get actionTestMicrophone => 'Testuj mikrofon';

  @override
  String get actionStopMicTest => 'Zatrzymaj test';

  @override
  String get tooltipAssistant => 'Asystent';

  @override
  String get tooltipAddEvent => 'Dodaj wydarzenie';

  @override
  String get assistantTitle => 'Asystent';

  @override
  String get assistantInputHint =>
      'Poproś mnie o zaplanowanie, znalezienie lub zmianę czegoś...';

  @override
  String get assistantRecordingHint =>
      'Słucham... dotknij mikrofonu ponownie, aby zatrzymać';

  @override
  String get assistantTranscribingHint => 'Transkrypcja...';

  @override
  String get assistantEmptyState =>
      'Poproś mnie o zaplanowanie, znalezienie lub zmianę czegoś w kalendarzu.';

  @override
  String assistantConfirmDeleteCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunąć tych $count wydarzeń?',
      many: 'Usunąć tych $count wydarzeń?',
      few: 'Usunąć te $count wydarzenia?',
      one: 'Usunąć to wydarzenie?',
    );
    return '$_temp0';
  }

  @override
  String assistantDeletedConfirmation(String title) {
    return 'Usunięto \"$title\".';
  }

  @override
  String assistantErrorGeneric(String error) {
    return 'Coś poszło nie tak: $error';
  }

  @override
  String reminderStartingNow(String title) {
    return '$title zaczyna się teraz';
  }

  @override
  String reminderWithLabel(String title, String label) {
    return '$title — $label';
  }
}
