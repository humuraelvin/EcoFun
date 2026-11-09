import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supa.dart';

enum Bucket {
  missions(false),
  scans(false),
  community(true),
  avatars(true);

  const Bucket(this.isPublic);
  final bool isPublic;
}

/// Uploads photos and resolves their URLs. Private buckets use signed URLs,
/// cached in memory so lists don't re-request them while scrolling.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final _signed = <String, (String, DateTime)>{};
  final _pending = <String, Future<String?>>{};
  final _rand = Random();

  /// A fresh object path inside the signed-in user's folder.
  String newPath() => '$currentUid/${_newName()}';

  String _newName() {
    final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final r = List.generate(6, (_) => _rand.nextInt(36).toRadixString(36)).join();
    return '$t$r.jpg';
  }

  /// Uploads JPEG bytes to `<bucket>/<uid>/<random>.jpg` and returns the object path.
  Future<String> uploadJpeg(Bucket bucket, Uint8List bytes, {String? path}) async {
    path ??= newPath();
    await supa.storage.from(bucket.name).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000', upsert: false),
        );
    return path;
  }

  String publicUrl(Bucket bucket, String path) => supa.storage.from(bucket.name).getPublicUrl(path);

  String? cachedUrl(Bucket bucket, String path) {
    if (bucket.isPublic) return publicUrl(bucket, path);
    final hit = _signed['${bucket.name}/$path'];
    if (hit != null && hit.$2.isAfter(DateTime.now())) return hit.$1;
    return null;
  }

  Future<String?> url(Bucket bucket, String path) {
    final cached = cachedUrl(bucket, path);
    if (cached != null) return Future.value(cached);
    final key = '${bucket.name}/$path';
    return _pending[key] ??= _sign(bucket, path, key).whenComplete(() => _pending.remove(key));
  }

  Future<String?> _sign(Bucket bucket, String path, String key) async {
    try {
      final url = await supa.storage.from(bucket.name).createSignedUrl(path, 60 * 60 * 6);
      _signed[key] = (url, DateTime.now().add(const Duration(hours: 5, minutes: 50)));
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Warm the cache for many private photos with one request.
  Future<void> preload(Bucket bucket, Iterable<String> paths) async {
    if (bucket.isPublic) return;
    final missing = paths.where((p) => cachedUrl(bucket, p) == null).toSet().toList();
    if (missing.isEmpty) return;
    try {
      final results = await supa.storage.from(bucket.name).createSignedUrlsResult(missing, 60 * 60 * 6);
      final expiry = DateTime.now().add(const Duration(hours: 5, minutes: 50));
      for (final r in results.whereType<SignedUrlSuccess>()) {
        _signed['${bucket.name}/${r.path}'] = (r.signedUrl, expiry);
      }
    } catch (_) {}
  }

  Future<void> deleteAllMine() => deleteAllOf(currentUid);

  /// Removes every file a member uploaded (their own, or any member's when called by an admin).
  Future<void> deleteAllOf(String uid) async {
    for (final b in Bucket.values) {
      try {
        while (true) {
          final files = await supa.storage.from(b.name).list(path: uid, searchOptions: const SearchOptions(limit: 100));
          if (files.isEmpty) break;
          await supa.storage.from(b.name).remove(files.map((f) => '$uid/${f.name}').toList());
          if (files.length < 100) break;
        }
      } catch (_) {}
    }
  }

  void clear() => _signed.clear();
}
