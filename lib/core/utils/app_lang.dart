/// The member's language, 'en' or 'rw' — the single source of truth for every text the app shows.
///
/// Set by the app root whenever the locale changes (the whole app rebuilds then), so model getters
/// such as `NewsArticle.title` always return text in this language.
abstract final class AppLang {
  static String code = 'rw';

  static bool get isRw => code == 'rw';
}
