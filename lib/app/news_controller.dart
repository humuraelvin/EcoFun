import 'package:get/get.dart' hide Trans;

import '../data/models.dart';
import '../data/repositories.dart';
import '../data/supa.dart';

/// Rwanda environment & climate news, collected hourly on the server from
/// Taarifa, Green Africa, KT Press, Rebero, Umuseke and Izuba.
class NewsController extends GetxController {
  static NewsController get to => Get.find();

  final articles = <NewsArticle>[].obs;
  final filter = RxnString(); // null = all, 'en', 'rw'
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

  Future<void> _boot() async {
    final cached = await NewsRepository.cached();
    if (articles.isEmpty && cached.isNotEmpty) articles.assignAll(cached);
    await refreshNews();
  }

  Future<void> refreshNews() async {
    loading.value = true;
    try {
      final list = await NewsRepository.list(language: filter.value);
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
      final more = await NewsRepository.list(language: filter.value, before: articles.last.publishedAt);
      final known = articles.map((a) => a.id).toSet();
      articles.addAll(more.where((a) => !known.contains(a.id)));
      hasMore.value = more.length >= NewsRepository.pageSize;
    } catch (_) {
    } finally {
      loadingMore.value = false;
    }
  }

  void setFilter(String? lang) {
    if (filter.value == lang) return;
    filter.value = lang;
    articles.clear();
    refreshNews();
  }

  /// Story featured on Home: the one being read today, otherwise the newest in the app language.
  NewsArticle? featured(String? todayArticleId, String lang) {
    if (articles.isEmpty) return null;
    if (todayArticleId != null) {
      final match = articles.firstWhereOrNull((a) => a.id == todayArticleId);
      if (match != null) return match;
    }
    return articles.firstWhereOrNull((a) => a.language == lang && a.imageUrl != null) ??
        articles.firstWhereOrNull((a) => a.language == lang) ??
        articles.first;
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
