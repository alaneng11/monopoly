import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../presentation/providers.dart';

/// شاشەی چوونەژوورەوە — پرۆفایلی ناوخۆیی (میوان) لەگەڵ پاشەکەوت.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە ناوێک بنوسە')),
      );
      return;
    }
    setState(() => _busy = true);
    await ref.read(profileProvider.notifier).setName(name);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ResponsiveCenter(maxWidth: 460, child: Column(
              children: [
                const SizedBox(height: 20),
                FadeInDown(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.goldGradient,
                      boxShadow: AppColors.goldGlow(),
                    ),
                    child: const Icon(Icons.castle, color: AppColors.night, size: 40),
                  ),
                ),
                const SizedBox(height: 18),
                Text('بەخێربێیت دیسانەوە', style: AppTextStyles.h1, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('ناوەکەت بنوسە و دەست بکە بە بازرگانی شارەکەت',
                    style: AppTextStyles.bodySoft, textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FadeInUp(
                  delay: const Duration(milliseconds: 150),
                  child: GlassContainer(
                    borderRadius: 28,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          style: AppTextStyles.body,
                          maxLength: 16,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _continueAsGuest(),
                          decoration: InputDecoration(
                            hintText: 'ناوی یاریزان',
                            counterText: '',
                            hintStyle: AppTextStyles.bodySoft,
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.gold, size: 20),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.glassBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.glassBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GoldenButton(
                          label: _busy ? 'چاوەڕوانبە...' : 'چوونەژوورەوە',
                          height: 54,
                          onTap: _busy ? null : _continueAsGuest,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeInUp(
                  delay: const Duration(milliseconds: 250),
                  child: Text(
                    'یاریی ئۆنلاین دوای ڕێکخستنی Firebase بەردەست دەبێت',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }
}
