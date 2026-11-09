import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/app_lang.dart';

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
  'Your account has been suspended.': 'errors.suspended',
  'New quiz questions are being prepared. Please try again in a minute.': 'errors.quizPreparing',
  'This quiz is no longer available. Start a new one.': 'errors.quizGone',
  'This quiz is no longer available.': 'errors.quizGone',
  'Choose one of the four answers.': 'errors.chooseAnswer',
  'This scan is no longer available.': 'errors.scanGone',
  'Scan a clear waste item first.': 'errors.scanUnclear',
  'The AI could not check this photo right now. Please try again.': 'errors.aiBusy',
  'Write a comment (up to 500 characters).': 'errors.commentLength',
  'You are commenting very fast. Take a short break.': 'errors.commentFast',
  'You can only delete your own comments.': 'errors.notYours',
  'Admins cannot be suspended.': 'errors.adminProtected',
  'Admins cannot be deleted here.': 'errors.adminProtected',
  'This member no longer exists.': 'errors.memberGone',
  'Points must be between -1000 and 1000.': 'errors.pointsRange',
  'Add a short reason.': 'errors.reason',
  'Write a title and a message.': 'errors.announceEmpty',
  'Translation is not available right now. Try again.': 'errors.translate',
  'Write a short story (up to 1,000 characters).': 'errors.storyLength',
  'Add a photo of your action.': 'errors.addPhoto',
  'Upload a photo first.': 'errors.addPhoto',
  'Choose 1 to 5 stars.': 'errors.generic',
};

/// True when the server or auth says this account is suspended.
bool isSuspendedError(Object error) {
  final m = (error is PostgrestException ? error.message : error is AuthException ? error.message : '$error').toLowerCase();
  return m.contains('suspended') || m.contains('banned');
}

/// Turns any thrown error into a short, human sentence in the current language.
String friendlyError(Object error) {
  if (error is SocketException || error is TimeoutException || error is HandshakeException) {
    return 'errors.offline'.tr();
  }
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('banned') || m.contains('suspended')) return 'errors.suspended'.tr();
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
    // Unknown auth messages are English: only English readers get the detail.
    return AppLang.isRw ? 'errors.generic'.tr() : error.message;
  }
  if (error is PostgrestException) {
    final key = _serverMessageKeys[error.message];
    if (key != null) return key.tr();
    if (error.code == 'PGRST202' || error.code == 'PGRST205' || error.code == '42883') {
      return 'errors.notSetUp'.tr();
    }
    if (error.code == '57014') return 'errors.slow'.tr();
    if (error.code == 'P0001') return AppLang.isRw ? 'errors.generic'.tr() : error.message;
    return 'errors.generic'.tr();
  }
  if (error is StorageException) return 'errors.upload'.tr();
  final text = error.toString().toLowerCase();
  if (text.contains('socket') || text.contains('failed host lookup') || text.contains('connection')) {
    return 'errors.offline'.tr();
  }
  return 'errors.generic'.tr();
}
