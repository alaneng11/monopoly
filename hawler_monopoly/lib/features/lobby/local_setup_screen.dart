import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/game_engine.dart';
import '../../domain/models/game_models.dart';
import '../../presentation/game_session_controller.dart';

class _Slot {
  String name;
  bool isAi;
  AiDifficulty difficulty;
  AiPersonality personality;
  String characterId;
  int colorIndex;
  _Slot({
    required this.name,
    required this.colorIndex,
    this.isAi = false,
    this.difficulty = AiDifficulty.medium,
    this.personality = AiPersonality.balanced,
  }) : characterId = TokenCharacter.all[colorIndex % TokenCharacter.all.length].id;
}

/// شاشەی ڕێکخستنی یاریی ناوخۆیی (Pass & Play) — ٢ تا ٦ یاریزان.
class LocalSetupScreen extends ConsumerStatefulWidget {
  const LocalSetupScreen({super.key});

  @override
  ConsumerState<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends ConsumerState<LocalSetupScreen> {
  static const _defaultNames = ['هێمن', 'ڕۆژان', 'کاوە', 'شادی', 'ئارام', 'دلنیا'];

  final List<_Slot> _slots = [
    _Slot(name: _defaultNames[0], colorIndex: 0, difficulty: AiDifficulty.medium, personality: AiPersonality.balanced),
    _Slot(name: _defaultNames[1], colorIndex: 1, isAi: true, difficulty: AiDifficulty.medium, personality: AiPersonality.balanced),
  ];
  final List<TextEditingController> _nameControllers = [
    TextEditingController(text: _defaultNames[0]),
    TextEditingController(text: _defaultNames[1]),
  ];

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    if (_slots.length >= GameEngine.maxPlayers) return;
    final i = _slots.length;
    setState(() {
      _slots.add(_Slot(name: _defaultNames[i], colorIndex: i, isAi: true));
      _nameControllers.add(TextEditingController(text: _defaultNames[i]));
    });
  }

  void _removePlayer(int index) {
    if (_slots.length <= GameEngine.minPlayers) return;
    setState(() {
      _slots.removeAt(index);
      final controller = _nameControllers.removeAt(index);
      controller.dispose();
    });
  }

  void _start() {
    final humans = _slots.where((s) => !s.isAi).length;
    if (humans < 1) {
      _showError('لانی کەم یەک مرۆڤ پێویستە بۆ Pass & Play');
      return;
    }
    if (_slots.any((s) => s.name.trim().isEmpty)) {
      _showError('ناوی هەموو یاریزانەکان پڕ بکەوە');
      return;
    }
    final names = _slots.map((s) => s.name.trim()).toList();
    if (names.toSet().length != names.length) {
      _showError('ناوی دووبارە هەیە');
      return;
    }
    for (var i = 0; i < _slots.length; i++) {
      _slots[i].colorIndex = i;
    }
    final setups = _slots
        .map((s) => PlayerSetup(
              id: 'p${s.colorIndex}_${s.isAi ? 'ai' : 'h'}',
              name: s.name.trim(),
              characterId: s.characterId,
              kind: s.isAi ? PlayerKind.ai : PlayerKind.human,
              aiDifficulty: s.difficulty,
              aiPersonality: s.personality,
            ))
        .toList();
    ref.read(gameSessionProvider.notifier).createLocalGame(setups);
    context.push('/game');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _slotColor(int i) {
    const palette = [
      AppColors.emerald,
      AppColors.sapphire,
      AppColors.ruby,
      AppColors.amethyst,
      AppColors.terracotta,
      Color(0xFF2AA5A0),
    ];
    return palette[i % palette.length];
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
                    CircleIconButton(icon: Icons.arrow_forward, onTap: () => context.pop()),
                    const SizedBox(width: 12),
                    Text('یاریی ناوخۆیی — Pass & Play', style: AppTextStyles.h2),
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
                        GlassContainer(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.phonelink, color: AppColors.gold, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'یاری لەسەر یەک مۆبایل — لە کۆتایی هەر ڕیزێک مۆبایلەکە دەگوازرێتەوە و زانیارییەکان دەشاردرێنەوە.',
                                  style: AppTextStyles.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < _slots.length; i++) ...[
                          _playerCard(i),
                          const SizedBox(height: 12),
                        ],
                        if (_slots.length < GameEngine.maxPlayers)
                          Center(
                            child: TextButton.icon(
                              onPressed: _addPlayer,
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.gold),
                              label: Text('زیادکردنی یاریزان (${_slots.length}/${GameEngine.maxPlayers})', style: AppTextStyles.goldLabel),
                            ),
                          ),
                        const SizedBox(height: 20),
                        GoldenButton(
                          label: 'دەستپێبکە',
                          icon: Icons.play_arrow_rounded,
                          height: 58,
                          onTap: _start,
                          width: double.infinity,
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

  Widget _playerCard(int i) {
    final slot = _slots[i];
    final color = _slotColor(i);
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: 0.4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ivory, width: 2),
                ),
                child: Center(child: Text('${i + 1}', style: AppTextStyles.titleMedium.copyWith(color: Colors.white))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameControllers[i],
                  onChanged: (v) => slot.name = v,
                  maxLength: 14,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'ناوی یاریزان',
                    counterText: '',
                    hintStyle: AppTextStyles.bodySoft,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              IconButton(
                onPressed: _slots.length > GameEngine.minPlayers ? () => _removePlayer(i) : null,
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _choiceChip(
                  label: 'مرۆڤ',
                  icon: Icons.person,
                  selected: !slot.isAi,
                  onTap: () => setState(() => slot.isAi = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _choiceChip(
                  label: 'کۆمپیوتەر',
                  icon: Icons.smart_toy,
                  selected: slot.isAi,
                  onTap: () => setState(() => slot.isAi = true),
                ),
              ),
            ],
          ),
          if (slot.isAi) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in AiDifficulty.values)
                  _miniChip(
                    label: _difficultyName(d),
                    selected: slot.difficulty == d,
                    onTap: () => setState(() => slot.difficulty = d),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in AiPersonality.values)
                  _miniChip(
                    label: _personalityName(p),
                    selected: slot.personality == p,
                    onTap: () => setState(() => slot.personality = p),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: TokenCharacter.all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, ci) {
                final ch = TokenCharacter.all[ci];
                final selected = slot.characterId == ch.id;
                return GestureDetector(
                  onTap: () => setState(() => slot.characterId = ch.id),
                  child: Tooltip(
                    message: ch.name,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: selected ? LinearGradient(colors: [color, color.withValues(alpha: 0.6)]) : null,
                        color: selected ? null : Colors.white.withValues(alpha: 0.06),
                        border: Border.all(color: selected ? AppColors.goldBright : AppColors.glassBorder, width: selected ? 2 : 1),
                      ),
                      child: Center(
                        child: Text(ch.emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _difficultyName(AiDifficulty d) => switch (d) {
        AiDifficulty.easy => 'ئاسان',
        AiDifficulty.medium => 'ناوەند',
        AiDifficulty.hard => 'قورس',
        AiDifficulty.expert => 'شارەزا',
      };

  String _personalityName(AiPersonality p) => switch (p) {
        AiPersonality.balanced => 'هاوسەنگ',
        AiPersonality.investor => 'وەبەرهێنەر',
        AiPersonality.aggressive => 'توندڕەو',
        AiPersonality.conservative => 'وریابین',
        AiPersonality.riskTaker => 'مەترسیخواز',
        AiPersonality.opportunist => 'دەرفەتخواز',
      };

  Widget _choiceChip({required String label, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        decoration: BoxDecoration(
          gradient: selected ? AppColors.goldButton : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: selected ? AppColors.gold : AppColors.glassBorder),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.night : AppColors.parchment),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.night : AppColors.parchment,
                fontWeight: FontWeight.w700,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.goldButton : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.gold : AppColors.glassBorder),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.night : AppColors.parchment,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
