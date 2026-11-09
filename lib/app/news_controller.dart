import 'package:get/get.dart' hide Trans;

import '../data/models.dart';
import '../data/repositories.dart';
import '../core/utils/app_lang.dart';
import '../data/supa.dart';
import 'session_controller.dart';

/// Rwanda environment & climate news, collected hourly on the server from
/// Taarifa, Green Africa, KT Press, Rebero, Umuseke and Izuba.
class NewsController extends GetxController {
  static NewsController get to => Get.find();

  final articles = <NewsArticle>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = true.obs;
  final error = RxnString();
  final readIds = <String>{}.obs;

  final _bodies = <String, NewsArticle>{};

  @override
  void onInit() {
    super.onInit();
    _boot();
  }

  /// Stories always follow the app language; switching language reloads them.
  String get _lang => AppLang.code;
  String? _loadedLang;

  Future<void> _boot() async {
    if (Get.isRegistered<SessionController>()) {
      ever<String>(SessionController.to.language, (_) => onLanguageChanged());
    }
    final cached = await NewsRepository.cached(_lang);
    if (articles.isEmpty && cached.isNotEmpty) articles.assignAll(cached);
    await refreshNews();
  }

  Future<void> onLanguageChanged() async {
    if (_loadedLang == _lang) return;
    _bodies.clear();
    articles.assignAll(await NewsRepository.cached(_lang));
    await refreshNews();
  }

  Future<void> refreshNews() async {
    loading.value = true;
    final lang = _lang;
    try {
      final list = await NewsRepository.list(language: lang);
      if (lang != _lang) return; // language changed while loading
      _loadedLang = lang;
      articles.assignAll(list);
      hasMore.value = list.length >= NewsRepository.pageSize;
      error.value = null;
      loadReads();
    } catch (e) {
      error.value = friendlyError(e);
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadReads() async {
    try {
      readIds.assignAll(await NewsRepository.readIds());
    } catch (_) {}
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore.value || articles.isEmpty) return;
    loadingMore.value = true;
    try {
      final more = await NewsRepository.list(language: _lang, before: articles.last.publishedAt);
      final known = articles.map((a) => a.id).toSet();
      articles.addAll(more.where((a) => !known.contains(a.id)));
      hasMore.value = more.length >= NewsRepository.pageSize;
    } catch (_) {
    } finally {
      loadingMore.value = false;
    }
  }

  /// Story featured on Home: the one being read today, otherwise the newest in the app language.
  NewsArticle? featured(String? todayArticleId, String lang) {
    if (articles.isEmpty) return null;
    if (todayArticleId != null) {
      final match = articles.firstWhereOrNull((a) => a.id == todayArticleId);
      if (match != null) return match;
    }
    // every listed story is readable in the app language; prefer one with a photo
    return articles.firstWhereOrNull((a) => a.imageUrl != null) ?? articles.first;
  }

  Future<NewsArticle> full(NewsArticle a) async {
    final hit = _bodies[a.id];
    if (hit != null) return hit;
    final fullArticle = await NewsRepository.full(a.id);
    _bodies[a.id] = fullArticle;
    if (_bodies.length > 25) _bodies.remove(_bodies.keys.first);
    return fullArticle;
  }

  void markLocallyRead(String id) => readIds.add(id);
}
