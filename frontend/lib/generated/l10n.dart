// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `no url provided`
  String get exceptionNoUrlToConnectToProvided {
    return Intl.message(
      'no url provided',
      name: 'exceptionNoUrlToConnectToProvided',
      desc: '',
      args: [],
    );
  }

  /// `no network available`
  String get noNetworkAvailable {
    return Intl.message(
      'no network available',
      name: 'noNetworkAvailable',
      desc: '',
      args: [],
    );
  }

  /// `mobile network not allowed`
  String get mobileNetworkNotAllowed {
    return Intl.message(
      'mobile network not allowed',
      name: 'mobileNetworkNotAllowed',
      desc: '',
      args: [],
    );
  }

  /// `couldn't reach`
  String get couldntReach {
    return Intl.message(
      'couldn\'t reach',
      name: 'couldntReach',
      desc: '',
      args: [],
    );
  }

  /// `no one is logged in so we refuse to get any data`
  String get wontFetchAnythingSinceNoOneIsLoggedIn {
    return Intl.message(
      'no one is logged in so we refuse to get any data',
      name: 'wontFetchAnythingSinceNoOneIsLoggedIn',
      desc: '',
      args: [],
    );
  }

  /// `could not parse response: `
  String get couldNotParseResponse {
    return Intl.message(
      'could not parse response: ',
      name: 'couldNotParseResponse',
      desc: '',
      args: [],
    );
  }

  /// `we sent the request but we didnt get any response`
  String get didntGetAnyResponseAfterSend {
    return Intl.message(
      'we sent the request but we didnt get any response',
      name: 'didntGetAnyResponseAfterSend',
      desc: '',
      args: [],
    );
  }

  /// `new image sending, this may take a sec`
  String get newImageSendingThisMayTakeASec {
    return Intl.message(
      'new image sending, this may take a sec',
      name: 'newImageSendingThisMayTakeASec',
      desc: '',
      args: [],
    );
  }

  /// `setting main image, this may take a sec`
  String get settingMainImageThisMayTakeASec {
    return Intl.message(
      'setting main image, this may take a sec',
      name: 'settingMainImageThisMayTakeASec',
      desc: '',
      args: [],
    );
  }

  /// `Deleting Image, this may take a sec`
  String get deletingImageThisMayTakeASec {
    return Intl.message(
      'Deleting Image, this may take a sec',
      name: 'deletingImageThisMayTakeASec',
      desc: '',
      args: [],
    );
  }

  /// `please wait, data is beeing synced`
  String get pleaseWaitDataIsBeeingSynced {
    return Intl.message(
      'please wait, data is beeing synced',
      name: 'pleaseWaitDataIsBeeingSynced',
      desc: '',
      args: [],
    );
  }

  /// `no response`
  String get noResponse {
    return Intl.message(
      'no response',
      name: 'noResponse',
      desc: '',
      args: [],
    );
  }

  /// `the body had no error field`
  String get theBodyHadNoErrorField {
    return Intl.message(
      'the body had no error field',
      name: 'theBodyHadNoErrorField',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong while communicating with the API`
  String get somethingWentWrongWhileCommunicatingWithTheApi {
    return Intl.message(
      'Something went wrong while communicating with the API',
      name: 'somethingWentWrongWhileCommunicatingWithTheApi',
      desc: '',
      args: [],
    );
  }

  /// `loading...`
  String get loading {
    return Intl.message(
      'loading...',
      name: 'loading',
      desc: '',
      args: [],
    );
  }

  /// `probier\'s nochmal`
  String get addingDataTryAgain {
    return Intl.message(
      'probier\\\'s nochmal',
      name: 'addingDataTryAgain',
      desc: '',
      args: [],
    );
  }

  /// `Irgendwas stimmt hier noch nicht`
  String get addingDataSomethingWrong {
    return Intl.message(
      'Irgendwas stimmt hier noch nicht',
      name: 'addingDataSomethingWrong',
      desc: '',
      args: [],
    );
  }

  /// `gib hier etwas ein`
  String get addingDataEnterSomethingHere {
    return Intl.message(
      'gib hier etwas ein',
      name: 'addingDataEnterSomethingHere',
      desc: '',
      args: [],
    );
  }

  /// `an error occured`
  String get anUnknownErrorOccured {
    return Intl.message(
      'an error occured',
      name: 'anUnknownErrorOccured',
      desc: '',
      args: [],
    );
  }

  /// `Not Available`
  String get notAvailable {
    return Intl.message(
      'Not Available',
      name: 'notAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Options for this image`
  String get optionsForThisImageHeadLine {
    return Intl.message(
      'Options for this image',
      name: 'optionsForThisImageHeadLine',
      desc: '',
      args: [],
    );
  }

  /// `permanently remove image`
  String get permanentlyRemoveImage {
    return Intl.message(
      'permanently remove image',
      name: 'permanentlyRemoveImage',
      desc: '',
      args: [],
    );
  }

  /// `set as main image`
  String get setAsMainImage {
    return Intl.message(
      'set as main image',
      name: 'setAsMainImage',
      desc: '',
      args: [],
    );
  }

  /// `share image`
  String get shareImage {
    return Intl.message(
      'share image',
      name: 'shareImage',
      desc: '',
      args: [],
    );
  }

  /// `Image`
  String get image {
    return Intl.message(
      'Image',
      name: 'image',
      desc: '',
      args: [],
    );
  }

  /// `see some Doggos`
  String get seeSomeDoggos {
    return Intl.message(
      'see some Doggos',
      name: 'seeSomeDoggos',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message(
      'Settings',
      name: 'settings',
      desc: '',
      args: [],
    );
  }

  /// `uploading..`
  String get uploading {
    return Intl.message(
      'uploading..',
      name: 'uploading',
      desc: '',
      args: [],
    );
  }

  /// `username or password was not given`
  String get usernameOrPasswordWasNotGiven {
    return Intl.message(
      'username or password was not given',
      name: 'usernameOrPasswordWasNotGiven',
      desc: '',
      args: [],
    );
  }

  /// `Login Credentials are beeing verified`
  String get loginCredentialsAreBeeingVerified {
    return Intl.message(
      'Login Credentials are beeing verified',
      name: 'loginCredentialsAreBeeingVerified',
      desc: '',
      args: [],
    );
  }

  /// `Bitte Kürzel eingeben`
  String get loginErrorPleaseEnterUserName {
    return Intl.message(
      'Bitte Kürzel eingeben',
      name: 'loginErrorPleaseEnterUserName',
      desc: '',
      args: [],
    );
  }

  /// `Kürzel`
  String get loginUsername {
    return Intl.message(
      'Kürzel',
      name: 'loginUsername',
      desc: '',
      args: [],
    );
  }

  /// `Bitte Passwort eingeben`
  String get loginErrorPleaseEnterPassword {
    return Intl.message(
      'Bitte Passwort eingeben',
      name: 'loginErrorPleaseEnterPassword',
      desc: '',
      args: [],
    );
  }

  /// `Passwort`
  String get loginLabelPassword {
    return Intl.message(
      'Passwort',
      name: 'loginLabelPassword',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get loginButton {
    return Intl.message(
      'Login',
      name: 'loginButton',
      desc: '',
      args: [],
    );
  }

  /// `uploadSync`
  String get uploadAndSyncData {
    return Intl.message(
      'uploadSync',
      name: 'uploadAndSyncData',
      desc: '',
      args: [],
    );
  }

  /// `advanced & experimental`
  String get advancedSettingsHeadline {
    return Intl.message(
      'advanced & experimental',
      name: 'advancedSettingsHeadline',
      desc: '',
      args: [],
    );
  }

  /// `Lokale Bilder löschen`
  String get deleteLocalImagesButton {
    return Intl.message(
      'Lokale Bilder löschen',
      name: 'deleteLocalImagesButton',
      desc: '',
      args: [],
    );
  }

  /// `Logout`
  String get logoutButton {
    return Intl.message(
      'Logout',
      name: 'logoutButton',
      desc: '',
      args: [],
    );
  }

  /// `Prüfpunkte`
  String get checkPointsTitle {
    return Intl.message(
      'Prüfpunkte',
      name: 'checkPointsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Fotos`
  String get imagesButton {
    return Intl.message(
      'Fotos',
      name: 'imagesButton',
      desc: '',
      args: [],
    );
  }

  /// `Kommentar`
  String get commentsOrDetailsButton {
    return Intl.message(
      'Kommentar',
      name: 'commentsOrDetailsButton',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get kurzTextHint {
    return Intl.message(
      'Name',
      name: 'kurzTextHint',
      desc: '',
      args: [],
    );
  }

  /// `Beschreibung`
  String get langTextHint {
    return Intl.message(
      'Beschreibung',
      name: 'langTextHint',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong`
  String get somethingWentWrong {
    return Intl.message(
      'Something went wrong',
      name: 'somethingWentWrong',
      desc: '',
      args: [],
    );
  }

  /// `Please drag down to reload this page`
  String get pleaseDragDownToReloadThisPage {
    return Intl.message(
      'Please drag down to reload this page',
      name: 'pleaseDragDownToReloadThisPage',
      desc: '',
      args: [],
    );
  }

  /// `delete unseccessful`
  String get deleteUnseccessful {
    return Intl.message(
      'delete unseccessful',
      name: 'deleteUnseccessful',
      desc: '',
      args: [],
    );
  }

  /// `sorry no image to upload`
  String get sorryNoImageToUpload {
    return Intl.message(
      'sorry no image to upload',
      name: 'sorryNoImageToUpload',
      desc: '',
      args: [],
    );
  }

  /// `upload finished (no idea whether successed or failed tho)`
  String get uploadFinishedNoIdeaWhetherSuccessedOrFailedTho {
    return Intl.message(
      'upload finished (no idea whether successed or failed tho)',
      name: 'uploadFinishedNoIdeaWhetherSuccessedOrFailedTho',
      desc: '',
      args: [],
    );
  }

  /// `Eigentümer`
  String get localtionOwner {
    return Intl.message(
      'Eigentümer',
      name: 'localtionOwner',
      desc: '',
      args: [],
    );
  }

  /// `Steigweg-Typ`
  String get locationWayUp {
    return Intl.message(
      'Steigweg-Typ',
      name: 'locationWayUp',
      desc: '',
      args: [],
    );
  }

  /// `Abschaltungen`
  String get locationAbschaltung {
    return Intl.message(
      'Abschaltungen',
      name: 'locationAbschaltung',
      desc: '',
      args: [],
    );
  }

  /// `SSSchlüssel`
  String get locationSteigschutzKey {
    return Intl.message(
      'SSSchlüssel',
      name: 'locationSteigschutzKey',
      desc: '',
      args: [],
    );
  }

  /// `Höhe`
  String get locationHeight {
    return Intl.message(
      'Höhe',
      name: 'locationHeight',
      desc: '',
      args: [],
    );
  }

  /// `Baujahr`
  String get locationYearOfBuild {
    return Intl.message(
      'Baujahr',
      name: 'locationYearOfBuild',
      desc: '',
      args: [],
    );
  }

  /// `WC Vorort`
  String get locationHasWCLabel {
    return Intl.message(
      'WC Vorort',
      name: 'locationHasWCLabel',
      desc: '',
      args: [],
    );
  }

  /// `Lagerraum verfügbar`
  String get locationHasStorageSpaceLabel {
    return Intl.message(
      'Lagerraum verfügbar',
      name: 'locationHasStorageSpaceLabel',
      desc: '',
      args: [],
    );
  }

  /// `update successful`
  String get updateSuccessful {
    return Intl.message(
      'update successful',
      name: 'updateSuccessful',
      desc: '',
      args: [],
    );
  }

  /// `Ansprechpartner nötig`
  String get locationASPRequieredLabel {
    return Intl.message(
      'Ansprechpartner nötig',
      name: 'locationASPRequieredLabel',
      desc: '',
      args: [],
    );
  }

  /// `Ansprechpartner`
  String get locationASPLabel {
    return Intl.message(
      'Ansprechpartner',
      name: 'locationASPLabel',
      desc: '',
      args: [],
    );
  }

  /// `Benötigt Schlüssel`
  String get locationRequiresKeyLabel {
    return Intl.message(
      'Benötigt Schlüssel',
      name: 'locationRequiresKeyLabel',
      desc: '',
      args: [],
    );
  }

  /// `Anmerkung Schlüssel`
  String get locationKeyAddintionalInfoLabel {
    return Intl.message(
      'Anmerkung Schlüssel',
      name: 'locationKeyAddintionalInfoLabel',
      desc: '',
      args: [],
    );
  }

  /// `Steckdosen verfügbar`
  String get locationHasSteckdosenLabel {
    return Intl.message(
      'Steckdosen verfügbar',
      name: 'locationHasSteckdosenLabel',
      desc: '',
      args: [],
    );
  }

  /// `Anmerkung Steckdosen`
  String get locationAdditionalInfoSteckdosenLabel {
    return Intl.message(
      'Anmerkung Steckdosen',
      name: 'locationAdditionalInfoSteckdosenLabel',
      desc: '',
      args: [],
    );
  }

  /// `dismiss`
  String get dismiss {
    return Intl.message(
      'dismiss',
      name: 'dismiss',
      desc: '',
      args: [],
    );
  }

  /// `ja, sicher, Löschen!`
  String get validateDeletionSure {
    return Intl.message(
      'ja, sicher, Löschen!',
      name: 'validateDeletionSure',
      desc: '',
      args: [],
    );
  }

  /// `wirklich Löschen?`
  String get validateDeletionPromtHeadline {
    return Intl.message(
      'wirklich Löschen?',
      name: 'validateDeletionPromtHeadline',
      desc: '',
      args: [],
    );
  }

  /// `diese Aktion ist entgültig und nicht wiederherstellbar`
  String get validateDeletionPromtWarning {
    return Intl.message(
      'diese Aktion ist entgültig und nicht wiederherstellbar',
      name: 'validateDeletionPromtWarning',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
