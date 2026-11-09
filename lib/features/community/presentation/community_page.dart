import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _isAdmin = false;
  bool _uploading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAdminClaim();
  }

  Future<void> _loadAdminClaim() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final result = await user.getIdTokenResult(true);
      if (mounted) setState(() => _isAdmin = result.claims?['admin'] == true);
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Community'),
      actions: [
        IconButton(
          tooltip: 'Leaderboard',
          onPressed: () => _tabs.animateTo(1),
          icon: const Icon(Icons.leaderboard),
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Community'),
          Tab(text: 'Leaderboard'),
        ],
      ),
    ),
    body: TabBarView(controller: _tabs, children: [_feed(), _leaderboard()]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _uploading ? null : _addImage,
      icon: _uploading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_a_photo_outlined),
      label: Text(_uploading ? 'Posting…' : 'Share a photo'),
    ),
  );

  Widget _feed() => Column(
    children: [
      if (_isAdmin)
        Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Admin portal'),
            subtitle: const Text('Grant points to a community member'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAdminGrant,
          ),
        ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          'Share a photo of an action that helps the environment. One image per post.',
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('communityPosts')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Could not load community posts.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = snapshot.data!.docs;
            if (posts.isEmpty) {
              return const Center(
                child: Text('No posts yet. Share the first photo!'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: posts.length,
              itemBuilder: (context, index) => _postCard(posts[index]),
            );
          },
        ),
      ),
    ],
  );

  Widget _postCard(QueryDocumentSnapshot<Map<String, dynamic>> post) {
    final data = post.data();
    final count = (data['ratingCount'] as num?)?.toInt() ?? 0;
    final total = (data['ratingTotal'] as num?)?.toInt() ?? 0;
    final authorId = data['uid'] as String? ?? '';
    final own = authorId == FirebaseAuth.instance.currentUser?.uid;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(
              data['fullName'] as String? ?? 'EcoStep member',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              count == 0
                  ? 'No ratings yet'
                  : '${(total / count).toStringAsFixed(1)} · $count ${count == 1 ? 'rating' : 'ratings'}',
            ),
            onTap: () => _openProfile(authorId),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              data['imageUrl'] as String? ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Text('Photo unavailable')),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('communityPosts')
                  .doc(post.id)
                  .collection('ratings')
                  .doc(FirebaseAuth.instance.currentUser?.uid ?? '_signed_out')
                  .snapshots(),
              builder: (context, snapshot) {
                final myRating = (snapshot.data?.data()?['value'] as num?)
                    ?.toInt();
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        myRating == null
                            ? 'Rate this action'
                            : 'You rated this · the author earned 1 point',
                      ),
                    ),
                    ...List.generate(
                      5,
                      (i) => IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34),
                        tooltip: '${i + 1} stars — gives the author 1 point',
                        icon: Icon(
                          myRating != null && i < myRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber.shade800,
                        ),
                        onPressed: own || myRating != null
                            ? null
                            : () => _rate(post.id, i + 1),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboard() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .orderBy('points', descending: true)
        .limit(100)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Could not load the leaderboard.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final users = snapshot.data!.docs;
      if (users.isEmpty) {
        return const Center(child: Text('The leaderboard is empty.'));
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final user = users[index];
          final data = user.data();
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(data['fullName'] as String? ?? 'EcoStep member'),
              subtitle: Text(
                '${(data['points'] as num?)?.toInt() ?? 0} points',
              ),
              trailing: index == 0
                  ? const Icon(Icons.emoji_events, color: Colors.amber)
                  : null,
              onTap: () => _openProfile(user.id),
            ),
          );
        },
      );
    },
  );

  Future<void> _addImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final photo = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 78,
    );
    if (photo == null) return;
    final file = File(photo.path);
    if (await file.length() > 5 * 1024 * 1024) {
      Get.snackbar('Image too large', 'Choose a photo smaller than 5 MB.');
      return;
    }
    setState(() => _uploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final objectPath =
          'community/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref(objectPath);
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      await FirebaseFunctions.instance
          .httpsCallable('createCommunityPost')
          .call({'objectPath': objectPath});
      Get.snackbar(
        'Photo shared',
        'Other members can rate your action. Each rating earns you 1 point.',
      );
    } catch (_) {
      Get.snackbar(
        'Could not share photo',
        'Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _rate(String postId, int value) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('rateCommunityPost')
          .call({'postId': postId, 'value': value});
      final data = Map<String, dynamic>.from(result.data as Map);
      Get.snackbar(
        data['alreadyRated'] == true ? 'Already rated' : 'Rating saved',
        data['alreadyRated'] == true
            ? 'You can rate each photo once.'
            : 'The author earned 1 point.',
      );
    } on FirebaseFunctionsException catch (error) {
      Get.snackbar('Could not rate photo', error.message ?? 'Try again later.');
    }
  }

  void _openProfile(String uid) {
    if (uid.isEmpty) return;
    Get.to(() => PublicMemberProfile(uid: uid));
  }

  Future<void> _showAdminGrant() async {
    final email = TextEditingController(),
        amount = TextEditingController(),
        reason = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant points'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Member email'),
              ),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Points (1–500)'),
              ),
              TextField(
                controller: reason,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await FirebaseFunctions.instance
                    .httpsCallable('adminGrantPoints')
                    .call({
                      'email': email.text.trim(),
                      'points': int.parse(amount.text),
                      'reason': reason.text.trim(),
                    });
                if (context.mounted) Navigator.pop(context);
                Get.snackbar(
                  'Points granted',
                  'The member’s profile has been updated.',
                );
              } catch (_) {
                Get.snackbar(
                  'Could not grant points',
                  'Check the email, points, reason, and your admin access.',
                );
              }
            },
            child: const Text('Grant'),
          ),
        ],
      ),
    );
    email.dispose();
    amount.dispose();
    reason.dispose();
  }
}

class PublicMemberProfile extends StatelessWidget {
  const PublicMemberProfile({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Member profile')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.data!.exists) {
          return const Center(child: Text('This profile is unavailable.'));
        }
        final profile = snapshot.data!.data()!;
        final photo = profile['photoURL'] as String?;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: photo == null ? null : NetworkImage(photo),
                  child: photo == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
                const SizedBox(height: 18),
                Text(
                  profile['fullName'] as String? ?? 'EcoStep member',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(profile['points'] as num?)?.toInt() ?? 0} points',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
