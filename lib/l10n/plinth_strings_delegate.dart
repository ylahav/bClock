import 'package:flutter/widgets.dart';
import 'package:plinth_components/plinth_components.dart';
import 'app_localizations.dart';

/// Feeds Plinth's built-in screen-reader labels from our ARB files, so a
/// modal's close button says "Fermer…" in French rather than "Close dialog".
/// Plinth's own `override` delegate carries one fixed set of strings, so
/// this resolves the set per locale instead.
class PlinthStringsDelegate extends LocalizationsDelegate<PlinthLocalizations> {
  const PlinthStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  @override
  Future<PlinthLocalizations> load(Locale locale) async {
    final l = await AppLocalizations.delegate.load(locale);
    return PlinthLocalizations(PlinthStrings(
      closeDialog: l.a11yCloseDialog,
      clearSearch: l.a11yClearSearch,
      clearSelection: l.a11yClearSelection,
    ));
  }

  @override
  bool shouldReload(PlinthStringsDelegate old) => false;
}
