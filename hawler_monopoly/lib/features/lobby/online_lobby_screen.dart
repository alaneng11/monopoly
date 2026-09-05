import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/online/online_repository.dart';
import '../../presentation/providers.dart';

/// هۆڵی یاریی ئۆنلاین — دروستکردنی ژوور، چوونەژوورەوە بە کۆد، و بینینی ژوورە گشتییەکان.
class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  final _codeController = TextEditingController();
  final _repo = RoomRepository.instance;
  List<Map<String, dynamic>> _publicRooms = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fetchPublicRooms();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _fetchPublicRooms() async {
    setState(() => _loading = true);
    final rooms = await _repo.getPublicRooms();
    if (!mounted) return;
    setState(() {
      _publicRooms = rooms;
      _loading = false;
    });
  }

  void _showCreateRoomDialog() {
    final nameController = TextEditingController();
    int maxPlayers = 4;
    int startCash = 1500;
    bool isPublic = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            gradient: AppColors.royalBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('دروستکردنی ژووری نوێ', style: AppTextStyles.h2),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: AppTextStyles.body,
                  maxLength: 24,
                  decoration: InputDecoration(
                    hintText: 'ناوی ژوور (نموونە: یاریی پاڵەوانان)',
                    counterText: '',
                    hintStyle: AppTextStyles.bodySoft,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('ژمارەی یاریزانەکان: $maxPlayers', style: AppTextStyles.titleMedium),
                Slider(
                  value: maxPlayers.toDouble(),
                  min: 2,
                  max: 6,
                  divisions: 4,
                  activeColor: AppColors.gold,
                  onChanged: (v) => setModalState(() => maxPlayers = v.toInt()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('ژووری گشتی (Public)', style: AppTextStyles.body),
                    const Spacer(),
                    Switch(
                      value: isPublic,
                      activeThumbColor: AppColors.gold,
                      onChanged: (v) => setModalState(() => isPublic = v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GoldenButton(
                  label: 'دروستکردن و چوونەژوورەوە',
                  height: 52,
                  icon: Icons.add_circle,
                  onTap: () async {
                    final profile = ref.read(profileProvider).value;
                    Navigator.pop(ctx);
                    setState(() => _busy = true);
                    try {
                      final room = await _repo.createRoom(
                        roomName: nameController.text.trim().isNotEmpty ? nameController.text.trim() : 'ژووری ${profile?.name ?? 'یاری'}',
                        playerName: profile?.name ?? 'یاریزان',
                        characterId: 'business',
                        isPublic: isPublic,
                        maxPlayers: maxPlayers,
                        startCash: startCash,
                      );
                      if (!mounted) return;
                      setState(() => _busy = false);
                      context.push('/room/${room.code}');
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => _busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('هەڵە: $e')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _joinByCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;

    final profile = ref.read(profileProvider).value;
    setState(() => _busy = true);
    try {
      final room = await _repo.joinRoom(
        code: clean,
        playerName: profile?.name ?? 'یاریزان',
        characterId: 'business',
      );
      if (!mounted) return;
      setState(() => _busy = false);
      context.push('/room/${room.code}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    CircleIconButton(icon: Icons.arrow_forward, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Text('یاریی ئۆنلاین', style: AppTextStyles.h2),
                    const Spacer(),
                    CircleIconButton(icon: Icons.refresh, onTap: _fetchPublicRooms),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ResponsiveCenter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Create Room Banner
                        FadeInDown(
                          child: GestureDetector(
                            onTap: _busy ? null : _showCreateRoomDialog,
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: AppColors.goldGlow(blur: 20),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_box_rounded, size: 40, color: AppColors.night),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('دروستکردنی ژوور', style: AppTextStyles.h3.copyWith(color: AppColors.night)),
                                        Text('ژوورێک بکەرەوە و کۆدەکەی بنێرە بۆ هاوڕێکانت',
                                            style: AppTextStyles.caption.copyWith(color: AppColors.night.withValues(alpha: 0.8), fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_left, color: AppColors.night),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Join by Code Input
                        FadeInUp(
                          child: GlassContainer(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('چوونەژوورەوە بە کۆد', style: AppTextStyles.titleMedium),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _codeController,
                                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2),
                                        textCapitalization: TextCapitalization.characters,
                                        maxLength: 8,
                                        decoration: InputDecoration(
                                          hintText: 'کۆدی ژوور (نموونە: ABCD)',
                                          counterText: '',
                                          hintStyle: AppTextStyles.bodySoft.copyWith(letterSpacing: 0),
                                          filled: true,
                                          fillColor: Colors.white.withValues(alpha: 0.06),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        ),
                                        onSubmitted: (v) => _joinByCode(v),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GoldenButton(
                                      label: _busy ? '...' : 'چوونەژوور',
                                      width: 100,
                                      height: 48,
                                      fontSize: 13,
                                      onTap: _busy ? null : () => _joinByCode(_codeController.text),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Public Rooms Section
                        const SectionHeader(title: 'ژوورە گشتییەکان'),
                        const SizedBox(height: 12),

                        if (_loading)
                          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.gold)))
                        else if (_publicRooms.isEmpty)
                          FadeInUp(
                            child: GlassContainer(
                              borderRadius: 20,
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.meeting_room_outlined, color: AppColors.gold.withValues(alpha: 0.4), size: 44),
                                    const SizedBox(height: 10),
                                    Text('هیچ ژوورێکی گشتی چالاک نییە', style: AppTextStyles.bodySoft),
                                    const SizedBox(height: 4),
                                    Text('ژوورێکی نوێ دروست بکە و چاوەڕێی یاریزانان بە', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _publicRooms.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final r = _publicRooms[i];
                              final code = r['code'] as String? ?? '';
                              final name = r['roomName'] as String? ?? 'ژووری یاری';
                              final count = (r['playerCount'] as num?)?.toInt() ?? 1;
                              final max = (r['maxPlayers'] as num?)?.toInt() ?? 6;

                              return FadeInUp(
                                delay: Duration(milliseconds: i * 50),
                                child: GlassContainer(
                                  borderRadius: 18,
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.sapphire.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.sapphire.withValues(alpha: 0.4)),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.groups, color: AppColors.sapphire, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: AppTextStyles.titleMedium),
                                            const SizedBox(height: 2),
                                            Text('کۆد: $code  •  یاریزان: $count/$max', style: AppTextStyles.caption.copyWith(color: AppColors.gold)),
                                          ],
                                        ),
                                      ),
                                      GoldenButton(
                                        label: 'بەشداربە',
                                        width: 84,
                                        height: 38,
                                        fontSize: 12,
                                        onTap: _busy ? null : () => _joinByCode(code),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
