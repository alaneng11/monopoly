import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/online/api_client.dart';
import '../../data/online/chat_repository.dart';
import '../../presentation/providers.dart';

/// شاشەی چوونەژوورەوە و تۆمارکردن — پشتگیری لە میوان و هەژماری فەرمی لە سێرڤەری Railway.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  int _tabIndex = 0; // 0: Guest, 1: Login, 2: Register
  final _guestNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _guestNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleGuest() async {
    final name = _guestNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'تکایە ناوێک بنووسە');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final res = await ApiClient.instance.guestLogin(displayName: name);
    if (!mounted) return;

    if (res.ok && res.data != null) {
      final user = res.data!['user'] as Map<String, dynamic>?;
      if (user != null) {
        await ref.read(profileProvider.notifier).syncWithServer(user);
      }
      ChatRepository.instance.init();
      context.go('/home');
    } else {
      setState(() {
        _busy = false;
        _errorMessage = res.error ?? 'هەڵەیەک ڕوویدا لە چوونەژوورەوە.';
      });
    }
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'تکایە ناو و وشەی نهێنی بنووسە');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final res = await ApiClient.instance.login(username: username, password: password);
    if (!mounted) return;

    if (res.ok && res.data != null) {
      final user = res.data!['user'] as Map<String, dynamic>?;
      if (user != null) {
        await ref.read(profileProvider.notifier).syncWithServer(user);
      }
      ChatRepository.instance.init();
      context.go('/home');
    } else {
      setState(() {
        _busy = false;
        _errorMessage = res.error ?? 'ناو یان وشەی نهێنی هەڵەیە.';
      });
    }
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (username.length < 3) {
      setState(() => _errorMessage = 'ناوی بەکارهێنەر دەبێت لانی کەم ٣ پیت بێت');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'وشەی نهێنی دەبێت لانی کەم ٦ پیت بێت');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final res = await ApiClient.instance.register(
      username: username,
      password: password,
      displayName: displayName.isNotEmpty ? displayName : username,
    );
    if (!mounted) return;

    if (res.ok && res.data != null) {
      final user = res.data!['user'] as Map<String, dynamic>?;
      if (user != null) {
        await ref.read(profileProvider.notifier).syncWithServer(user);
      }
      ChatRepository.instance.init();
      context.go('/home');
    } else {
      setState(() {
        _busy = false;
        _errorMessage = res.error ?? 'هەڵەیەک ڕوویدا لە دروستکردنی هەژمار.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ResponsiveCenter(
              maxWidth: 460,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  FadeInDown(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                        boxShadow: AppColors.goldGlow(),
                      ),
                      child: const Icon(Icons.castle, color: AppColors.night, size: 40),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('مۆنۆپۆلی هەولێر', style: AppTextStyles.h1, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    'شاری قەڵا و منارە — یاریی بازرگانیی شکۆدار',
                    style: AppTextStyles.bodySoft,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Tab Selector
                  GlassContainer(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _tabButton(0, 'میوان (خێرا)'),
                        _tabButton(1, 'چوونەژوورەوە'),
                        _tabButton(2, 'تۆمارکردن'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.caption.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  FadeInUp(
                    key: ValueKey(_tabIndex),
                    child: GlassContainer(
                      borderRadius: 26,
                      padding: const EdgeInsets.all(22),
                      child: _tabIndex == 0
                          ? _guestForm()
                          : _tabIndex == 1
                              ? _loginForm()
                              : _registerForm(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _tabIndex = index;
          _errorMessage = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active ? AppColors.goldGradient : null,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: active ? AppColors.night : AppColors.parchment,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _guestForm() {
    return Column(
      children: [
        Text('ناوی خۆت دیاریبکە بۆ دەستپێکی خێرا:', style: AppTextStyles.bodySoft),
        const SizedBox(height: 14),
        TextField(
          controller: _guestNameController,
          style: AppTextStyles.body,
          maxLength: 16,
          decoration: InputDecoration(
            hintText: 'ناوی یاریزان (نموونە: ئالان)',
            counterText: '',
            hintStyle: AppTextStyles.bodySoft,
            prefixIcon: const Icon(Icons.person_outline, color: AppColors.gold, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        GoldenButton(
          label: _busy ? 'چاوەڕوانبە...' : 'چوونەژوورەوە وەک میوان',
          height: 52,
          icon: Icons.play_arrow,
          onTap: _busy ? null : _handleGuest,
        ),
      ],
    );
  }

  Widget _loginForm() {
    return Column(
      children: [
        TextField(
          controller: _usernameController,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'ناوی بەکارهێنەر (Username)',
            hintStyle: AppTextStyles.bodySoft,
            prefixIcon: const Icon(Icons.account_circle_outlined, color: AppColors.gold, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'وشەی نهێنی (Password)',
            hintStyle: AppTextStyles.bodySoft,
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.gold, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        GoldenButton(
          label: _busy ? 'چاوەڕوانبە...' : 'چوونەژوورەوە',
          height: 52,
          icon: Icons.login,
          onTap: _busy ? null : _handleLogin,
        ),
      ],
    );
  }

  Widget _registerForm() {
    return Column(
      children: [
        TextField(
          controller: _displayNameController,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'ناوی پیشاندراو (Display Name)',
            hintStyle: AppTextStyles.bodySoft,
            prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.gold, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _usernameController,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'ناوی بەکارهێنەر (Username - بە ئینگلیزی)',
            hintStyle: AppTextStyles.bodySoft,
            prefixIcon: const Icon(Icons.person_outline, color: AppColors.gold, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'وشەی نهێنی (لانی کەم ٦ پیت)',
            hintStyle: AppTextStyles.bodySoft,
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.gold, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        GoldenButton(
          label: _busy ? 'چاوەڕوانبە...' : 'دروستکردنی هەژمار',
          height: 52,
          icon: Icons.person_add_alt_1,
          onTap: _busy ? null : _handleRegister,
        ),
      ],
    );
  }
}
