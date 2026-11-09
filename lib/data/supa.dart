import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supa => Supabase.instance.client;

String get currentUid {
  final id = supa.auth.currentUser?.id;
  if (id == null) throw const AuthException('Not signed in');
  return id;
}

/// Calls a Postgres function and returns its JSON result.
Future<T> rpc<T>(String fn, [Map<String, dynamic>? params]) async {
  final result = await supa.rpc(fn, params: params);
  return result as T;
}

/// Server messages we know how to translate. Everything else falls back to a generic line.
const _serverMessageKeys = {
  "Read today's story first.": 'errors.readFirst',
  "Finish today's quiz first.": 'errors.quizFirst',
  "You already completed today's mission.": 'errors.missionDone',
  'Answer every question first.': 'errors.answerAll',
  'This quiz is not available today.': 'errors.quizUnavailable',
  'The AI could not analyse this photo right now. Please try again.': 'errors.aiBusy',
  'You cannot rate your own post.': 'errors.ownPost',
  'This post is no longer available.': 'errors.postGone',
  'Admin access is required.': 'errors.notAdmin',
  'No member uses that email.': 'errors.noMember',
  'The photo is too large. Try again.': 'errors.photoTooLarge',
  "You reached today's scan limit. Come back tomorrow!": 'errors.scanLimit',
  'You can share up to 10 photos a day.': 'errors.postLimit',
  'This story is no longer available.': 'errors.storyGone',
};

/// Turns any thrown error into a short, human sentence in the current language.
String friendlyError(Object error) {
  if (error is SocketException || error is TimeoutException || error is HandshakeException) {
    return 'errors.offline'.tr();
  }
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) return 'errors.badLogin'.tr();
    if (m.contains('email not confirmed')) return 'errors.emailNotConfirmed'.tr();
    if (m.contains('already registered') || m.contains('already exists')) return 'errors.emailTaken'.tr();
    if (m.contains('password') && (m.contains('at least') || m.contains('weak') || m.contains('short'))) {
      return 'errors.weakPassword'.tr();
    }
    if (m.contains('expired') || m.contains('invalid') && m.contains('otp') || m.contains('token')) {
      return 'errors.badCode'.tr();
    }
    if (m.contains('rate limit') || m.contains('too many') || error.statusCode == '429') {
      return 'errors.rateLimited'.tr();
    }
    if (m.contains('network') || m.contains('socket') || m.contains('failed host lookup')) {
      return 'errors.offline'.tr();
    }
    return error.message;
  }
  if (error is PostgrestException) {
    final key = _serverMessageKeys[error.message];
    if (key != null) return key.tr();
    if (error.code == 'PGRST202' || error.code == 'PGRST205' || error.code == '42883') {
      return 'errors.notSetUp'.tr();
    }
    if (error.code == '57014') return 'errors.slow'.tr();
    if (error.code == 'P0001') return error.message;
    return 'errors.generic'.tr();
  }
  if (error is StorageException) return 'errors.upload'.tr();
  final text = error.toString().toLowerCase();
  if (text.contains('socket') || text.contains('failed host lookup') || text.contains('connection')) {
    return 'errors.offline'.tr();
  }
  return 'errors.generic'.tr();
}
