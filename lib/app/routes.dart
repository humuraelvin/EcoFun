import 'package:get/get.dart' hide Trans;

import '../features/auth/login_view.dart';
import '../features/auth/reset_password_view.dart';
import '../features/admin/admin_reports_view.dart';
import '../features/admin/admin_shell.dart';
import '../features/admin/admin_user_view.dart';
import '../features/community/compose_view.dart';
import '../features/community/member_view.dart';
import '../features/community/post_view.dart';
import '../features/history/history_detail_view.dart';
import '../features/history/history_view.dart';
import '../features/mission/mission_view.dart';
import '../features/news/news_detail_view.dart';
import '../features/notifications/notifications_view.dart';
import '../features/onboarding/onboarding_view.dart';
import '../features/quiz/quiz_view.dart';
import '../features/scan/camera_view.dart';
import '../features/scan/scan_result_view.dart';
import '../features/scan/scan_view.dart';
import '../features/shell/shell_view.dart';

abstract final class Routes {
  static const welcome = '/welcome';
  static const login = '/login';
  static const reset = '/reset';
  static const shell = '/';
  static const news = '/news';
  static const quiz = '/quiz';
  static const mission = '/mission';
  static const camera = '/camera';
  static const scanResult = '/scan';
  static const scans = '/scans';
  static const history = '/history';
  static const historyDetail = '/history/detail';
  static const compose = '/community/compose';
  static const member = '/member';
  static const admin = '/admin';
  static const adminUser = '/admin/user';
  static const adminReports = '/admin/reports';
  static const post = '/post';
  static const notifications = '/notifications';

  static final pages = <GetPage<dynamic>>[
    GetPage(name: welcome, page: () => const OnboardingView(), transition: Transition.fadeIn),
    GetPage(name: login, page: () => const LoginView(), transition: Transition.fadeIn),
    GetPage(name: reset, page: () => const ResetPasswordView()),
    GetPage(name: shell, page: () => const ShellView(), transition: Transition.fadeIn),
    GetPage(name: news, page: () => const NewsDetailView()),
    GetPage(name: quiz, page: () => const QuizView(), fullscreenDialog: true, transition: Transition.downToUp),
    GetPage(name: mission, page: () => const MissionView()),
    GetPage(name: camera, page: () => const CameraView(), fullscreenDialog: true, transition: Transition.downToUp),
    GetPage(name: scanResult, page: () => const ScanResultView()),
    GetPage(name: scans, page: () => const ScansView()),
    GetPage(name: history, page: () => const HistoryView()),
    GetPage(name: historyDetail, page: () => const HistoryDetailView()),
    GetPage(name: compose, page: () => const ComposeView(), fullscreenDialog: true, transition: Transition.downToUp),
    GetPage(name: member, page: () => const MemberView()),
    GetPage(name: admin, page: () => const AdminShell(), transition: Transition.fadeIn),
    GetPage(name: adminUser, page: () => const AdminUserView()),
    GetPage(name: adminReports, page: () => const AdminReportsView()),
    GetPage(name: post, page: () => const PostView()),
    GetPage(name: notifications, page: () => const NotificationsView()),
  ];
}
