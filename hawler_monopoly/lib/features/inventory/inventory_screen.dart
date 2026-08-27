import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final owned = [
      ('کڵاوی شاهانە', FontAwesomeIcons.crown, true),
      ('پارچەی زێڕین', FontAwesomeIcons.chessKnight, true),
      ('چوارچێوەی VIP', FontAwesomeIcons.borderAll, false),
      ('دیزاینی تەختە', FontAwesomeIcons.chessBoard, true),
      ('پیجی تایبەت', FontAwesomeIcons.gem, false),
      ('باکگراوندی شەو', FontAwesomeIcons.moon, true),
    ];
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
                    Text('کۆگای من', style: AppTextStyles.h2),
                  ],
                ),
              ),
              Expanded(
                child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: owned.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Breakpoints.gridColumns(context),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, i) {
                    final item = owned[i];
                    return FadeInUp(
                      delay: Duration(milliseconds: 50 * i),
                      child: GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(14),
                        borderColor: item.$3 ? AppColors.gold.withValues(alpha: 0.5) : AppColors.glassBorder,
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: Icon(item.$2, color: AppColors.gold, size: 34),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(item.$1, style: AppTextStyles.caption, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: item.$3
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                item.$3 ? 'چالاک' : 'بەکارهێنان',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.caption.copyWith(
                                  color: item.$3 ? AppColors.success : AppColors.parchment,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
