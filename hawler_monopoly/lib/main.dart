import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/achievements/achievements_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/board/board_screen.dart';
import 'features/home/home_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/lobby/lobby_screen.dart';
import 'features/lobby/local_setup_screen.dart';
import 'features/lobby/online_lobby_screen.dart';
import 'features/lobby/room_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/rewards/daily_rewards_screen.dart';
import 'features/rewards/challenges_screen.dart';
import 'features/profile/match_history_screen.dart';
import 'features/property/collections_screen.dart';
import 'features/social/friends_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/splash/splash_screen.dart';

import 'core/services/sound_service.dart';
import 'data/local/persistence.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load settings and configure SoundService on startup
  try {
    final settings = await LocalPersistence.loadSettings();
    SoundService.instance.configure(
      sound: settings['sound'] as bool? ?? true,
      vibration: settings['vibration'] as bool? ?? true,
    );
  } catch (_) {}
  runApp(const ProviderScope(child: HawlerMonopolyApp()));
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/lobby', builder: (_, __) => const LobbyScreen()),
    GoRoute(path: '/online-lobby', builder: (_, __) => const OnlineLobbyScreen()),
    GoRoute(
      path: '/room/:code',
      builder: (_, state) => RoomScreen(roomCode: state.pathParameters['code'] ?? ''),
    ),
    GoRoute(path: '/local-setup', builder: (_, __) => const LocalSetupScreen()),
    GoRoute(path: '/game', builder: (_, __) => const BoardScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/shop', builder: (_, __) => const ShopScreen()),
    GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
    GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
    GoRoute(path: '/rewards', builder: (_, __) => const DailyRewardsScreen()),
    GoRoute(path: '/achievements', builder: (_, __) => const AchievementsScreen()),
    GoRoute(path: '/challenges', builder: (_, __) => const ChallengesScreen()),
    GoRoute(path: '/match-history', builder: (_, __) => const MatchHistoryScreen()),
    GoRoute(path: '/collections', builder: (_, __) => const CollectionsScreen()),
    GoRoute(path: '/friends', builder: (_, __) => const FriendsScreen()),
  ],
);

/// ڕیشەی ئەپلیکەیشن — "مۆنۆپۆلی هەولێر"
/// پشتگیری تەواو لە زمانی کوردی (سۆرانی) و ئاڕاستەی RTL + Riverpod + GoRouter.
class HawlerMonopolyApp extends StatelessWidget {
  const HawlerMonopolyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'مۆنۆپۆلی هەولێر',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
  }
}
