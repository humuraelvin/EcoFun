import 'dart:io';

import 'package:eco_step/features/news/domain/entities/news_entity.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

class NewsRepositoryImpl {
  static final _feeds = <_NewsFeed>[
    _NewsFeed(
      Uri.https('news.google.com', '/rss/search', {
        'q': 'Rwanda (climate OR environment OR conservation OR biodiversity)',
        'hl': 'en-RW',
        'gl': 'RW',
        'ceid': 'RW:en',
      }),
      languageCode: 'en',
      defaultSource: 'Google News',
    ),
    _NewsFeed(
      Uri.parse('https://rebero.rw/category/ibidukikije/feed/'),
      languageCode: 'rw',
      defaultSource: 'Rebero',
    ),
    _NewsFeed(
      Uri.parse('https://izubaradiotv.rw/rss/latest-posts'),
      languageCode: 'rw',
      defaultSource: 'Izuba',
    ),
  ];

  final http.Client _client;

  NewsRepositoryImpl({http.Client? client}) : _client = client ?? http.Client();

  Future<List<NewsEntity>> getNews() async {
    final resultSets = await Future.wait(_feeds.map(_fetchFeed));
    final articles = resultSets.expand((items) => items).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final seen = <String>{};
    return articles
        .where((article) {
          final key = article.articleUrl.isNotEmpty
              ? article.articleUrl
              : article.title.toLowerCase();
          return seen.add(key);
        })
        .take(40)
        .toList();
  }

  Future<List<NewsEntity>> _fetchFeed(_NewsFeed feed) async {
    try {
      final response = await _client
          .get(feed.uri, headers: const {'User-Agent': 'EcoStep/1.0'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) return [];

      final document = XmlDocument.parse(response.body);
      return document
          .findAllElements('item')
          .map((item) {
            final title = _text(item, 'title');
            final description = _cleanDescription(_text(item, 'description'));
            final link = _text(item, 'link');
            final publishedAt = _parseDate(_text(item, 'pubDate'));
            final publisher = _text(item, 'source');
            return NewsEntity(
              id: link.isNotEmpty ? link : title,
              title: title,
              content: description.isEmpty ? title : description,
              coverImageUrl: 'assets/images/cover.png',
              authorName: publisher.isEmpty ? feed.defaultSource : publisher,
              publishedDate: DateFormat(
                'MMMM d, y',
                'en_US',
              ).format(publishedAt),
              publishedAt: publishedAt,
              newsSource: publisher.isEmpty ? feed.defaultSource : publisher,
              articleUrl: link,
              languageCode: feed.languageCode,
              contentImages: const [],
            );
          })
          .where((article) {
            final articleUri = Uri.tryParse(article.articleUrl);
            return article.title.trim().isNotEmpty &&
                articleUri != null &&
                const {'http', 'https'}.contains(articleUri.scheme) &&
                (feed.languageCode != 'rw' ||
                    (_looksKinyarwanda(article.title) &&
                        _looksEnvironmental(
                          '${article.title} ${article.content}',
                        )));
          })
          .toList();
    } catch (_) {
      // Keep usable results from the other feed if one provider is unavailable.
      return [];
    }
  }

  String _text(XmlElement item, String name) =>
      item.getElement(name)?.innerText.trim() ?? '';

  DateTime _parseDate(String value) {
    try {
      return HttpDate.parse(value).toLocal();
    } catch (_) {
      try {
        return DateFormat(
          "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
          'en_US',
        ).parseUtc(value).toLocal();
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
  }

  String _cleanDescription(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _looksKinyarwanda(String title) {
    final text = title.toLowerCase();
    const indicators = [
      'u rwanda',
      'igihugu',
      'ibidukikije',
      'ikirere',
      'imihindagurikire',
      'ibinyabuzima',
      'imyanda',
      'ubuhinzi',
      'kurengera',
      'kubungabunga',
      'abaturage',
      'umushinga',
      'inkangu',
      'imvura',
      'amazi',
      'ubutaka',
      'ibiti',
    ];
    return indicators.any(text.contains);
  }

  bool _looksEnvironmental(String text) {
    final normalized = text.toLowerCase();
    const topics = [
      'ibidukikije',
      'ikirere',
      'imihindagurikire',
      'imyanda',
      'amazi',
      'ubutaka',
      'ibiti',
      'amashyamba',
      'ubuhinzi',
      'isuri',
      'imvura',
      'umwuka',
      'karuboni',
      'ibinyabuzima',
      'inyamaswa',
      'inkangu',
      'ibiza',
      'ibihe',
    ];
    return topics.any(normalized.contains);
  }
}

class _NewsFeed {
  const _NewsFeed(
    this.uri, {
    required this.languageCode,
    required this.defaultSource,
  });

  final Uri uri;
  final String languageCode;
  final String defaultSource;
}
