import 'package:eco_step/features/news/data/repositories/news_repository_impl.dart';
import 'package:eco_step/features/news/domain/entities/news_entity.dart';
import 'package:get/get.dart';

class NewsViewModel extends GetxController {
  NewsViewModel({NewsRepositoryImpl? repository})
    : _repository = repository ?? NewsRepositoryImpl();

  final NewsRepositoryImpl _repository;
  final RxList<NewsEntity> _newsList = <NewsEntity>[].obs;
  final RxBool _isLoading = true.obs;
  final RxString _errorMessage = ''.obs;
  final RxString _selectedDate = '23'.obs;
  final RxInt _selectedDateIndex = 3.obs;
  final RxMap<String, double> _readingProgress = <String, double>{}.obs;

  List<NewsEntity> get newsList => _newsList;
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;
  String get selectedDate => _selectedDate.value;
  int get selectedDateIndex => _selectedDateIndex.value;
  Map<String, double> get readingProgress => _readingProgress;

  @override
  void onInit() {
    super.onInit();
    refreshNews();
  }

  Future<void> refreshNews() async {
    _isLoading.value = true;
    _errorMessage.value = '';
    try {
      final articles = await _repository.getNews();
      _newsList.assignAll(articles);
      if (articles.isEmpty) {
        _errorMessage.value =
            'No Rwanda environment news is available right now.';
      }
    } catch (_) {
      _errorMessage.value =
          'Could not load news. Check your connection and try again.';
    } finally {
      _isLoading.value = false;
    }
  }

  void selectDate(int index, String date) {
    _selectedDateIndex.value = index;
    _selectedDate.value = date;
  }

  NewsEntity? getTodayNews() => _newsList.isEmpty ? null : _newsList.first;

  double getNewsReadingProgress(String newsId) =>
      _readingProgress[newsId] ?? 0.0;

  void updateReadingProgress(String newsId, double progress) {
    _readingProgress[newsId] = progress;
  }
}
