import 'package:eco_step/features/history/domain/entities/history_item.dart';
import 'package:eco_step/features/history/domain/repositories/history_repository.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  @override
  Future<List<HistoryItem>> getHistoryItems() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final items = [
      HistoryItem(
        id: '1',
        title: 'Use a reusable tumbler',
        content:
            'I used my own tumbler instead of a disposable cup and received a discount at the café.',
        createdAt: today,
        timeString: '',
        isToday: true,
        imageUrl: 'https://example.com/tumbler.jpg',
      ),
      HistoryItem(
        id: '2',
        title: 'Take public transportation',
        content:
            'I took the train to work instead of driving, helping reduce carbon emissions.',
        createdAt: today.subtract(const Duration(days: 1)),
        timeString: '',
        isToday: false,
        imageUrl: 'https://example.com/subway.jpg',
      ),
      HistoryItem(
        id: '3',
        title: 'Sort recycling',
        content:
            'I sorted plastic, paper, and glass so recyclable materials could be processed properly.',
        createdAt: today.subtract(const Duration(days: 2)),
        timeString: '',
        isToday: false,
        imageUrl: 'https://example.com/recycle.jpg',
      ),
      HistoryItem(
        id: '4',
        title: 'Choose an e-receipt',
        content:
            'I chose an electronic receipt instead of a paper one to reduce paper use.',
        createdAt: today.subtract(const Duration(days: 3)),
        timeString: '',
        isToday: false,
      ),
      HistoryItem(
        id: '5',
        title: 'Bring a reusable shopping bag',
        content:
            'I used a reusable bag for groceries instead of taking a plastic bag.',
        createdAt: today.subtract(const Duration(days: 4)),
        timeString: '',
        isToday: false,
        imageUrl: 'https://example.com/ecobag.jpg',
      ),
      HistoryItem(
        id: '6',
        title: 'Take the stairs',
        content:
            'I took the stairs instead of the elevator to save electricity and get some exercise.',
        createdAt: today.subtract(const Duration(days: 5)),
        timeString: '',
        isToday: false,
      ),
      HistoryItem(
        id: '7',
        title: 'Save water',
        content:
            'I saved water by turning off the tap while brushing and taking a shorter shower.',
        createdAt: today.subtract(const Duration(days: 6)),
        timeString: '',
        isToday: false,
      ),
    ];

    return items;
  }

  @override
  Future<HistoryItem?> getHistoryItemById(String id) async {
    final items = await getHistoryItems();
    try {
      return items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }
}
