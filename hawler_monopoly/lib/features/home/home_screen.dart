import 'dart:async';

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/online/chat_repository.dart';
import '../../domain/models/chat_models.dart';
import '../../presentation/providers.dart';
import '../lobby/lobby_screen.dart';
import '../shop/shop_screen.dart';
import '../profile/profile_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../rewards/daily_rewards_screen.dart';
import '../achievements/achievements_screen.dart';
import '../settings/settings_screen.dart';
import '../inventory/inventory_screen.dart';
import '../rewards/challenges_screen.dart';
import '../property/collections_screen.dart';
import '../profile/match_history_screen.dart';
import '../social/friends_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;
  List<FriendProfile> _friends = [];
  StreamSubscription<List<FriendProfile>>? _friendsSub;

  @override
  void initState() {
    super.initState();
    _friendsSub = ChatRepository.instance.watchFriends().listen((f) {
      if (mounted) setState(() => _friends = f);
    });
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    super.dispose();
  }

  void _push(Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim),
            child: screen,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: ResponsiveCenter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        FadeInUp(child: _welcomeBanner()),
                        const SizedBox(height: 24),
                        FadeInUp(delay: const Duration(milliseconds: 100), child: _playCta()),
                        const SizedBox(height: 28),
                        const SectionHeader(title: 'دەستپێکی خێرا'),
                        const SizedBox(height: 14),
                        FadeInUp(delay: const Duration(milliseconds: 150), child: _quickGrid()),
                        const SizedBox(height: 28),
                        SectionHeader(
                          title: 'دۆستەکان', actionLabel: 'هەمووی', onAction: () => _push(const FriendsScreen()),
                        ),
                        const SizedBox(height: 14),
                        FadeInUp(delay: const Duration(milliseconds: 200), child: _friendsRow()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _topBar() {
    final profile = ref.watch(profileProvider).value;
    final name = profile?.name ?? 'یاریزان';
    final initials = name.isNotEmpty ? name.substring(0, 1) : '؟';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _push(const ProfileScreen()),
            child: AvatarRing(size: 52, initials: initials, level: profile?.level ?? 1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ((profile?.xpInLevel ?? 0) / 1000).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CurrencyPill(icon: KurdishIcons.coin, value: _formatCoins(profile?.coins ?? 0)),
          const SizedBox(width: 8),
          CurrencyPill(icon: KurdishIcons.gem, value: '${profile?.gems ?? 0}', color: AppColors.sapphire),
        ],
      ),
    );
  }

  String _formatCoins(int v) => v >= 10000 ? '${(v / 1000).toStringAsFixed(1)}K' : '$v';

  Widget _welcomeBanner() {
    return GlassContainer(
      borderRadius: 26,
      gradient: AppColors.citadelCard,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('خەڵاتی ڕۆژانە', style: AppTextStyles.h3),
                const SizedBox(height: 6),
                Text('ئەمڕۆ بچۆرە ژوورەوە و زێڕ وەربگرە',
                    style: AppTextStyles.caption, maxLines: 2),
                const SizedBox(height: 12),
                GoldenButton(
                  label: 'وەریگرە',
                  height: 40,
                  fontSize: 13,
                  onTap: () => _push(const DailyRewardsScreen()),
                ),
              ],
            ),
          ),
          const Icon(FontAwesomeIcons.gift, color: AppColors.goldBright, size: 54),
        ],
      ),
    );
  }

  Widget _playCta() {
    return GestureDetector(
      onTap: () => _push(const LobbyScreen()),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppColors.goldGlow(blur: 30),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -10,
              bottom: -10,
              child: Icon(Icons.castle, size: 120, color: AppColors.night.withValues(alpha: 0.12)),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('دەستپێبکە بە یاری',
                            style: AppTextStyles.h2.copyWith(color: AppColors.night)),
                        const SizedBox(height: 6),
                        Text('بازاڕی هەولێر چاوەڕێتە',
                            style: AppTextStyles.bodySoft.copyWith(
                                color: AppColors.night.withValues(alpha: 0.75))),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.night,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: AppColors.goldBright, size: 34),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickGrid() {
    final items = [
      (_QuickItem('یاری خێرا', FontAwesomeIcons.diceD6, AppColors.emerald), () => _push(const LobbyScreen())),
      (_QuickItem('کۆگا', FontAwesomeIcons.boxOpen, AppColors.sapphire), () => _push(const InventoryScreen())),
      (_QuickItem('بازاڕ', FontAwesomeIcons.store, AppColors.ruby), () => _push(const ShopScreen())),
      (_QuickItem('ئەفتخارات', FontAwesomeIcons.medal, AppColors.amethyst), () => _push(const AchievementsScreen())),
      (_QuickItem('داواکارییەکان', FontAwesomeIcons.bullseye, AppColors.terracotta), () => _push(const ChallengesScreen())),
      (_QuickItem('کۆگای موڵک', FontAwesomeIcons.layerGroup, AppColors.info), () => _push(const CollectionsScreen())),
      (_QuickItem('تۆماری یاری', FontAwesomeIcons.clockRotateLeft, AppColors.parchment), () => _push(const MatchHistoryScreen())),
      (_QuickItem('هاوڕێکان', Icons.people, AppColors.emerald), () => _push(const FriendsScreen())),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 380
            ? 2
            : constraints.maxWidth < 560
                ? 3
                : 4;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.08,
          children: items.map((e) {
            final item = e.$1;
            return GestureDetector(
              onTap: e.$2,
              child: GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                borderColor: item.color.withValues(alpha: 0.25),
                fillColor: item.color.withValues(alpha: 0.08),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [item.color.withValues(alpha: 0.35), item.color.withValues(alpha: 0.12)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: item.color.withValues(alpha: 0.35)),
                      ),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.label,
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _friendsRow() {
    if (_friends.isEmpty) {
      return GlassContainer(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.person_add_outlined, color: AppColors.gold, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('هیچ هاوڕێیەکت نییە هێشتا', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text('هاوڕێ زیاد بکە بۆ یاریکردن پێکەوە', style: AppTextStyles.bodySoft),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _push(const FriendsScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('زیادکردن', style: AppTextStyles.caption.copyWith(color: AppColors.night, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final f = _friends[i];
          final initials = f.name.isNotEmpty ? f.name.substring(0, 1) : '?';
          return GestureDetector(
            onTap: () => _push(const FriendsScreen()),
            child: Column(
              children: [
                Stack(
                  children: [
                    AvatarRing(size: 56, initials: initials, level: f.level),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: f.status == FriendOnlineStatus.online ? AppColors.success : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.night, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  f.name.length > 8 ? '${f.name.substring(0, 7)}…' : f.name,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bottomNav() {
    final tabs = [
      (Icons.home_rounded, 'ماڵەوە'),
      (Icons.leaderboard_rounded, 'پلەبەندی'),
      (FontAwesomeIcons.diceD6, 'یاری'),
      (Icons.store_rounded, 'بازاڕ'),
      (Icons.settings_rounded, 'ڕێکخستن'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GlassContainer(
        borderRadius: 28,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(tabs.length, (i) {
            final selected = i == _navIndex;
            return GestureDetector(
              onTap: () {
                setState(() => _navIndex = i);
                if (i == 1) _push(const LeaderboardScreen());
                if (i == 2) _push(const LobbyScreen());
                if (i == 3) _push(const ShopScreen());
                if (i == 4) _push(const SettingsScreen());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.goldGradient : null,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  tabs[i].$1,
                  size: 20,
                  color: selected ? AppColors.night : AppColors.parchment.withValues(alpha: 0.6),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _QuickItem {
  final String label;
  final IconData icon;
  final Color color;
  _QuickItem(this.label, this.icon, this.color);
}
