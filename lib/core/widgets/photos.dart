import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Network image decoded at the size it is shown (saves memory on low-end phones).
class NetPhoto extends StatelessWidget {
  const NetPhoto({
    super.key,
    required this.url,
    this.cacheKey,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.placeholderIcon = CupertinoIcons.photo,
  });

  final String? url;
  final String? cacheKey;
  final BoxFit fit;
  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final placeholder = ColoredBox(
      color: c.fill,
      child: Center(child: Icon(placeholderIcon, color: c.tertiaryLabel, size: 26)),
    );
    final image = LayoutBuilder(builder: (context, box) {
      if (url == null || url!.isEmpty) return placeholder;
      final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.5);
      final w = box.maxWidth.isFinite ? (box.maxWidth * dpr).round() : 900;
      return CachedNetworkImage(
        imageUrl: url!,
        cacheKey: cacheKey,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: w.clamp(64, 1200),
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => ColoredBox(color: c.fill),
        errorWidget: (_, _, _) => placeholder,
      );
    });
    return radius == 0 ? image : ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

/// Image stored in a Supabase bucket (signed URL for private buckets).
class StoragePhoto extends StatelessWidget {
  const StoragePhoto({super.key, required this.bucket, required this.path, this.radius = 0, this.fit = BoxFit.cover});

  final Bucket bucket;
  final String? path;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) return NetPhoto(url: null, radius: radius);
    final store = StorageService.instance;
    final cached = store.cachedUrl(bucket, path!);
    if (cached != null) {
      return NetPhoto(url: cached, cacheKey: '${bucket.name}/$path', radius: radius, fit: fit);
    }
    return FutureBuilder<String?>(
      future: store.url(bucket, path!),
      builder: (context, snap) => NetPhoto(
        url: snap.data,
        cacheKey: '${bucket.name}/$path',
        radius: radius,
        fit: fit,
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 40});

  final String name;
  final String? url;
  final double size;

  static const _palette = [
    Color(0xFF0C9F5C), Color(0xFF0A84FF), Color(0xFFEA6A12), Color(0xFF8E5CF7),
    Color(0xFFE5372B), Color(0xFF0FA3B1), Color(0xFFD6A100), Color(0xFF5E7D2F),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(_initials, style: AppText.headline.copyWith(fontSize: size * 0.38, color: Colors.white)),
    );
    if (url == null || url!.isEmpty) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          fit: BoxFit.cover,
          memCacheWidth: (size * 2.5).round(),
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
          fadeInDuration: const Duration(milliseconds: 150),
        ),
      ),
    );
  }
}
