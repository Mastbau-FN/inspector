import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @addingDataEnterSomethingHere.
  ///
  /// In de, this message translates to:
  /// **'gib hier etwas ein'**
  String get addingDataEnterSomethingHere;

  /// No description provided for @addingDataSomethingWrong.
  ///
  /// In de, this message translates to:
  /// **'Irgendwas stimmt hier noch nicht'**
  String get addingDataSomethingWrong;

  /// No description provided for @addingDataTryAgain.
  ///
  /// In de, this message translates to:
  /// **'probier\\\'s nochmal'**
  String get addingDataTryAgain;

  /// No description provided for @advancedSettingsHeadline.
  ///
  /// In de, this message translates to:
  /// **'erweitert & experimentell'**
  String get advancedSettingsHeadline;

  /// No description provided for @allow.
  ///
  /// In de, this message translates to:
  /// **'erlauben'**
  String get allow;

  /// No description provided for @allowNotifications.
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen erlauben'**
  String get allowNotifications;

  /// No description provided for @anUnknownErrorOccured.
  ///
  /// In de, this message translates to:
  /// **'unbekannter Fehler'**
  String get anUnknownErrorOccured;

  /// No description provided for @areYouSure.
  ///
  /// In de, this message translates to:
  /// **'Es sind noch Mängel vorhanden. Bitte zuerst alle Mängel löschen'**
  String get areYouSure;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'abbrechen'**
  String get cancel;

  /// No description provided for @checkPointsTitle.
  ///
  /// In de, this message translates to:
  /// **'Prüfpunkte'**
  String get checkPointsTitle;

  /// No description provided for @commentsOrDetailsButton.
  ///
  /// In de, this message translates to:
  /// **'Kommentar'**
  String get commentsOrDetailsButton;

  /// No description provided for @couldNotParseResponse.
  ///
  /// In de, this message translates to:
  /// **'Antwort nicht verstanden:'**
  String get couldNotParseResponse;

  /// No description provided for @couldntReach.
  ///
  /// In de, this message translates to:
  /// **'nicht erreichbar'**
  String get couldntReach;

  /// No description provided for @deleteLocalImagesButton.
  ///
  /// In de, this message translates to:
  /// **'Lokale Bilder löschen'**
  String get deleteLocalImagesButton;

  /// No description provided for @deleteUnseccessful.
  ///
  /// In de, this message translates to:
  /// **'Löschen erfolglos'**
  String get deleteUnseccessful;

  /// No description provided for @deletingImageThisMayTakeASec.
  ///
  /// In de, this message translates to:
  /// **'Bild wird gelöscht'**
  String get deletingImageThisMayTakeASec;

  /// No description provided for @developerOptions.
  ///
  /// In de, this message translates to:
  /// **'Entwickler-Optionen'**
  String get developerOptions;

  /// No description provided for @didntGetAnyResponseAfterSend.
  ///
  /// In de, this message translates to:
  /// **'keine Antwort'**
  String get didntGetAnyResponseAfterSend;

  /// No description provided for @didYouMisclick.
  ///
  /// In de, this message translates to:
  /// **'Verklickt?'**
  String get didYouMisclick;

  /// No description provided for @dismiss.
  ///
  /// In de, this message translates to:
  /// **'doch nicht'**
  String get dismiss;

  /// No description provided for @exceptionNoUrlToConnectToProvided.
  ///
  /// In de, this message translates to:
  /// **'no url provided'**
  String get exceptionNoUrlToConnectToProvided;

  /// No description provided for @heightNotOptional.
  ///
  /// In de, this message translates to:
  /// **'Bitte Höhe angeben'**
  String get heightNotOptional;

  /// No description provided for @image.
  ///
  /// In de, this message translates to:
  /// **'Foto'**
  String get image;

  /// No description provided for @imagesButton.
  ///
  /// In de, this message translates to:
  /// **'Fotos'**
  String get imagesButton;

  /// No description provided for @kurzTextHint.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get kurzTextHint;

  /// No description provided for @langTextHint.
  ///
  /// In de, this message translates to:
  /// **'Beschreibung'**
  String get langTextHint;

  /// No description provided for @loading.
  ///
  /// In de, this message translates to:
  /// **'lädt...'**
  String get loading;

  /// No description provided for @localtionOwner.
  ///
  /// In de, this message translates to:
  /// **'Eigentümer'**
  String get localtionOwner;

  /// No description provided for @locationAbschaltung.
  ///
  /// In de, this message translates to:
  /// **'Abschaltungen'**
  String get locationAbschaltung;

  /// No description provided for @locationAdditionalInfoSteckdosenLabel.
  ///
  /// In de, this message translates to:
  /// **'Steckdosentyp (Volt/Ampere)'**
  String get locationAdditionalInfoSteckdosenLabel;

  /// No description provided for @locationASPLabel.
  ///
  /// In de, this message translates to:
  /// **'Name Ansprechpartner'**
  String get locationASPLabel;

  /// No description provided for @locationASPRequieredLabel.
  ///
  /// In de, this message translates to:
  /// **'Ansprechpartner nötig'**
  String get locationASPRequieredLabel;

  /// No description provided for @locationHasSteckdosenLabel.
  ///
  /// In de, this message translates to:
  /// **'Steckdosen'**
  String get locationHasSteckdosenLabel;

  /// No description provided for @locationHasStorageSpaceLabel.
  ///
  /// In de, this message translates to:
  /// **'Lagerraum'**
  String get locationHasStorageSpaceLabel;

  /// No description provided for @locationHasWCLabel.
  ///
  /// In de, this message translates to:
  /// **'WC'**
  String get locationHasWCLabel;

  /// No description provided for @locationHeight.
  ///
  /// In de, this message translates to:
  /// **'Höhe'**
  String get locationHeight;

  /// No description provided for @locationKeyAddintionalInfoLabel.
  ///
  /// In de, this message translates to:
  /// **'Anmerkung Schlüssel'**
  String get locationKeyAddintionalInfoLabel;

  /// No description provided for @locationRequiresKeyLabel.
  ///
  /// In de, this message translates to:
  /// **'Schlüssel'**
  String get locationRequiresKeyLabel;

  /// No description provided for @locationSteigschutzKey.
  ///
  /// In de, this message translates to:
  /// **'Steigschutz-Schlüssel'**
  String get locationSteigschutzKey;

  /// No description provided for @locationWayUp.
  ///
  /// In de, this message translates to:
  /// **'Steigweg-Typ'**
  String get locationWayUp;

  /// No description provided for @locationYearOfBuild.
  ///
  /// In de, this message translates to:
  /// **'Baujahr'**
  String get locationYearOfBuild;

  /// No description provided for @loginButton.
  ///
  /// In de, this message translates to:
  /// **'Einloggen'**
  String get loginButton;

  /// No description provided for @loginCredentialsAreBeeingVerified.
  ///
  /// In de, this message translates to:
  /// **'prüfe Login-Daten'**
  String get loginCredentialsAreBeeingVerified;

  /// No description provided for @loginErrorPleaseEnterPassword.
  ///
  /// In de, this message translates to:
  /// **'Bitte Passwort eingeben'**
  String get loginErrorPleaseEnterPassword;

  /// No description provided for @loginErrorPleaseEnterUserName.
  ///
  /// In de, this message translates to:
  /// **'Bitte Kürzel eingeben'**
  String get loginErrorPleaseEnterUserName;

  /// No description provided for @loginLabelPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get loginLabelPassword;

  /// No description provided for @loginUsername.
  ///
  /// In de, this message translates to:
  /// **'Kürzel'**
  String get loginUsername;

  /// No description provided for @logoutButton.
  ///
  /// In de, this message translates to:
  /// **'Logout'**
  String get logoutButton;

  /// No description provided for @mobileNetworkNotAllowed.
  ///
  /// In de, this message translates to:
  /// **'mobile Netzwerke nicht erlaubt'**
  String get mobileNetworkNotAllowed;

  /// No description provided for @newImageSendingThisMayTakeASec.
  ///
  /// In de, this message translates to:
  /// **'Bild wird hochgeladen'**
  String get newImageSendingThisMayTakeASec;

  /// No description provided for @noNetworkAvailable.
  ///
  /// In de, this message translates to:
  /// **'Kein Netzwerk verfügbar'**
  String get noNetworkAvailable;

  /// No description provided for @nonetwork_forcedOfflineMode.
  ///
  /// In de, this message translates to:
  /// **'Netzwerk Zugriff hierfür verboten'**
  String get nonetwork_forcedOfflineMode;

  /// No description provided for @noResponse.
  ///
  /// In de, this message translates to:
  /// **'keine Antwort vom Server'**
  String get noResponse;

  /// No description provided for @notAvailable.
  ///
  /// In de, this message translates to:
  /// **'nicht verfügbar'**
  String get notAvailable;

  /// No description provided for @noViableInternetConnection.
  ///
  /// In de, this message translates to:
  /// **'keine valide InternetVerbindung'**
  String get noViableInternetConnection;

  /// No description provided for @option_canbeoffline.
  ///
  /// In de, this message translates to:
  /// **'kann Offline'**
  String get option_canbeoffline;

  /// No description provided for @option_canusemobilenetworkifpossible.
  ///
  /// In de, this message translates to:
  /// **'Mobilfunknetz nutzen'**
  String get option_canusemobilenetworkifpossible;

  /// No description provided for @option_debugallresponses.
  ///
  /// In de, this message translates to:
  /// **'debugAllResponses'**
  String get option_debugallresponses;

  /// No description provided for @option_debugimages.
  ///
  /// In de, this message translates to:
  /// **'debugImages'**
  String get option_debugimages;

  /// No description provided for @option_debuglocalmirror.
  ///
  /// In de, this message translates to:
  /// **'debugLocalMirror'**
  String get option_debuglocalmirror;

  /// No description provided for @option_forceOffline.
  ///
  /// In de, this message translates to:
  /// **'Offline-Modus erzwingen'**
  String get option_forceOffline;

  /// No description provided for @option_infinitelyreloadpictures.
  ///
  /// In de, this message translates to:
  /// **'infinitelyreloadPictures'**
  String get option_infinitelyreloadpictures;

  /// No description provided for @option_mergeloadeddataintoonlinedata.
  ///
  /// In de, this message translates to:
  /// **'offline Daten mit Online vervollständigen'**
  String get option_mergeloadeddataintoonlinedata;

  /// No description provided for @option_mergeloadeddataintoonlinedataevenincachedparent.
  ///
  /// In de, this message translates to:
  /// **'offline Daten mit Online vervollständigen, selbst wenn wir im offline-modus sind'**
  String get option_mergeloadeddataintoonlinedataevenincachedparent;

  /// No description provided for @option_preferremotedata.
  ///
  /// In de, this message translates to:
  /// **'Daten vom Server bevorzugen'**
  String get option_preferremotedata;

  /// No description provided for @option_preferremoteimages.
  ///
  /// In de, this message translates to:
  /// **'Bilder vom Server bevorzugen'**
  String get option_preferremoteimages;

  /// No description provided for @optionsForThisImageHeadLine.
  ///
  /// In de, this message translates to:
  /// **'Bildoptionen'**
  String get optionsForThisImageHeadLine;

  /// No description provided for @option_showdoggo.
  ///
  /// In de, this message translates to:
  /// **'showDoggo'**
  String get option_showdoggo;

  /// No description provided for @option_tryOnlineIfOfflineFailed.
  ///
  /// In de, this message translates to:
  /// **'probier online-Verfahren wenn es offline gescheitert ist'**
  String get option_tryOnlineIfOfflineFailed;

  /// No description provided for @option_compactDownload.
  ///
  /// In de, this message translates to:
  /// **'kompakten Download (stark komprimierte Bilder) nutzen'**
  String get option_compactDownload;

  /// No description provided for @option_tryonlinerequestincachedmode.
  ///
  /// In de, this message translates to:
  /// **'probier online-Verfahren obwohl wir offline sind'**
  String get option_tryonlinerequestincachedmode;

  /// No description provided for @option_usemobilenetworkfordownload.
  ///
  /// In de, this message translates to:
  /// **'mobiles Netz zum runterladen nutzen'**
  String get option_usemobilenetworkfordownload;

  /// No description provided for @option_usemobilenetworkforupload.
  ///
  /// In de, this message translates to:
  /// **'mobiles Netz zum hochladen nutzen'**
  String get option_usemobilenetworkforupload;

  /// No description provided for @option_usesystemtheme.
  ///
  /// In de, this message translates to:
  /// **'System Stil statt MBG Palette nutzen'**
  String get option_usesystemtheme;

  /// No description provided for @permanentlyRemoveImage.
  ///
  /// In de, this message translates to:
  /// **'Bild dauerhaft löschen'**
  String get permanentlyRemoveImage;

  /// No description provided for @pleaseDragDownToReloadThisPage.
  ///
  /// In de, this message translates to:
  /// **'bitte neu laden'**
  String get pleaseDragDownToReloadThisPage;

  /// No description provided for @pleaseWaitDataIsBeeingSynced.
  ///
  /// In de, this message translates to:
  /// **'Daten werden synchronisiert'**
  String get pleaseWaitDataIsBeeingSynced;

  /// No description provided for @plsWait.
  ///
  /// In de, this message translates to:
  /// **'bitte warten'**
  String get plsWait;

  /// No description provided for @positionHeightHint.
  ///
  /// In de, this message translates to:
  /// **'Position / Höhe / Ort'**
  String get positionHeightHint;

  /// No description provided for @seeSomeDoggos.
  ///
  /// In de, this message translates to:
  /// **'see some Doggos'**
  String get seeSomeDoggos;

  /// No description provided for @setAsMainImage.
  ///
  /// In de, this message translates to:
  /// **'als Vorschaubild setzen'**
  String get setAsMainImage;

  /// No description provided for @settingMainImageThisMayTakeASec.
  ///
  /// In de, this message translates to:
  /// **'Vorschaubild wird gesetzt'**
  String get settingMainImageThisMayTakeASec;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @shareImage.
  ///
  /// In de, this message translates to:
  /// **'Fotos teilen'**
  String get shareImage;

  /// No description provided for @somethingWentWrong.
  ///
  /// In de, this message translates to:
  /// **'irgendwas lief schief, bitte nochmal versuchen'**
  String get somethingWentWrong;

  /// No description provided for @somethingWentWrongWhileCommunicatingWithTheApi.
  ///
  /// In de, this message translates to:
  /// **'Etwas ist in bei der Kommunikation mit der API fehlgeschlagen'**
  String get somethingWentWrongWhileCommunicatingWithTheApi;

  /// No description provided for @sorryNoImageToUpload.
  ///
  /// In de, this message translates to:
  /// **'kein Bild zum Upload'**
  String get sorryNoImageToUpload;

  /// No description provided for @theBodyHadNoErrorField.
  ///
  /// In de, this message translates to:
  /// **'the body had no error field'**
  String get theBodyHadNoErrorField;

  /// No description provided for @tryAgainLater_noNetwork.
  ///
  /// In de, this message translates to:
  /// **'probiere es später nochmal'**
  String get tryAgainLater_noNetwork;

  /// No description provided for @updateSuccessful.
  ///
  /// In de, this message translates to:
  /// **'Update erfolgreich'**
  String get updateSuccessful;

  /// No description provided for @uploadAndSyncData.
  ///
  /// In de, this message translates to:
  /// **'Synchronisierung mit Server'**
  String get uploadAndSyncData;

  /// No description provided for @uploadFinishedNoIdeaWhetherSuccessedOrFailedTho.
  ///
  /// In de, this message translates to:
  /// **'Upload durchgeführt'**
  String get uploadFinishedNoIdeaWhetherSuccessedOrFailedTho;

  /// No description provided for @uploading.
  ///
  /// In de, this message translates to:
  /// **'wird hochgeladen...'**
  String get uploading;

  /// No description provided for @usernameOrPasswordWasNotGiven.
  ///
  /// In de, this message translates to:
  /// **'Name oder Passwort nicht angegeben'**
  String get usernameOrPasswordWasNotGiven;

  /// No description provided for @validateDeletionPromtHeadline.
  ///
  /// In de, this message translates to:
  /// **'wirklich Löschen?'**
  String get validateDeletionPromtHeadline;

  /// No description provided for @validateDeletionPromtWarning.
  ///
  /// In de, this message translates to:
  /// **'diese Aktion ist entgültig und nicht wiederherstellbar'**
  String get validateDeletionPromtWarning;

  /// No description provided for @validateDeletionSure.
  ///
  /// In de, this message translates to:
  /// **'ja, sicher, Löschen!'**
  String get validateDeletionSure;

  /// No description provided for @weCanSendYouANotificationAboutTheSyncProgress.
  ///
  /// In de, this message translates to:
  /// **'Wir wurden dich gerne über den Synchronisationsfortschritt informieren'**
  String get weCanSendYouANotificationAboutTheSyncProgress;

  /// No description provided for @wontFetchAnythingSinceNoOneIsLoggedIn.
  ///
  /// In de, this message translates to:
  /// **'Niemand eingelogt'**
  String get wontFetchAnythingSinceNoOneIsLoggedIn;

  /// No description provided for @ohneMaengel.
  ///
  /// In de, this message translates to:
  /// **'mangelfrei'**
  String get ohneMaengel;

  /// No description provided for @uhoh.
  ///
  /// In de, this message translates to:
  /// **'Uuups'**
  String get uhoh;

  /// No description provided for @defectLocation.
  ///
  /// In de, this message translates to:
  /// **'Ort: {location}'**
  String defectLocation(Object location);

  /// No description provided for @defectInfo.
  ///
  /// In de, this message translates to:
  /// **'Info: {info}'**
  String defectInfo(Object info);

  /// No description provided for @unknown.
  ///
  /// In de, this message translates to:
  /// **'unbekannt'**
  String get unknown;
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
