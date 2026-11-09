import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Flutter ships no Kinyarwanda strings for its built-in widgets. These fill in the labels members
/// can actually see (text selection menu, back/close buttons, dialogs, search, pull to refresh),
/// so a Kinyarwanda member never meets English there either.
class RwMaterialLocalizations extends DefaultMaterialLocalizations {
  const RwMaterialLocalizations();

  @override
  String get copyButtonLabel => 'Kopora';
  @override
  String get cutButtonLabel => 'Kata';
  @override
  String get pasteButtonLabel => 'Omeka';
  @override
  String get selectAllButtonLabel => 'Hitamo byose';
  @override
  String get shareButtonLabel => 'Sangiza';
  @override
  String get searchWebButtonLabel => 'Shakisha kuri interineti';
  @override
  String get lookUpButtonLabel => 'Shakisha';
  @override
  String get backButtonTooltip => 'Subira inyuma';
  @override
  String get closeButtonTooltip => 'Funga';
  @override
  String get closeButtonLabel => 'Funga';
  @override
  String get cancelButtonLabel => 'Hagarika';
  @override
  String get okButtonLabel => 'Yego';
  @override
  String get continueButtonLabel => 'Komeza';
  @override
  String get deleteButtonTooltip => 'Siba';
  @override
  String get moreButtonTooltip => 'Ibindi';
  @override
  String get showMenuTooltip => 'Erekana urutonde';
  @override
  String get searchFieldLabel => 'Shakisha';
  @override
  String get clearButtonTooltip => 'Siba inyandiko';
  @override
  String get modalBarrierDismissLabel => 'Funga';
  @override
  String get dialogLabel => 'Ikiganiro';
  @override
  String get alertDialogLabel => 'Imenyesha';
  @override
  String get refreshIndicatorSemanticLabel => 'Vugurura';
  @override
  String get scrimLabel => 'Funga';
  @override
  String get bottomSheetLabel => 'Urupapuro rwo hasi';

  static const LocalizationsDelegate<MaterialLocalizations> delegate = _RwMaterialDelegate();
}

class _RwMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _RwMaterialDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'rw';
  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(const RwMaterialLocalizations());
  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) => false;
}

class RwCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const RwCupertinoLocalizations();

  @override
  String get copyButtonLabel => 'Kopora';
  @override
  String get cutButtonLabel => 'Kata';
  @override
  String get pasteButtonLabel => 'Omeka';
  @override
  String get selectAllButtonLabel => 'Hitamo byose';
  @override
  String get shareButtonLabel => 'Sangiza';
  @override
  String get searchWebButtonLabel => 'Shakisha kuri interineti';
  @override
  String get lookUpButtonLabel => 'Shakisha';
  @override
  String get searchTextFieldPlaceholderLabel => 'Shakisha';
  @override
  String get modalBarrierDismissLabel => 'Funga';
  @override
  String get alertDialogLabel => 'Imenyesha';
  @override
  String get backButtonLabel => 'Subira';
  @override
  String get cancelButtonLabel => 'Hagarika';
  @override
  String get clearButtonLabel => 'Siba';
  @override
  String get noSpellCheckReplacementsLabel => 'Nta byasimbura byabonetse';
  @override
  String get menuDismissLabel => 'Funga urutonde';

  static const LocalizationsDelegate<CupertinoLocalizations> delegate = _RwCupertinoDelegate();
}

class _RwCupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _RwCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'rw';
  @override
  Future<CupertinoLocalizations> load(Locale locale) => SynchronousFuture(const RwCupertinoLocalizations());
  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) => false;
}
