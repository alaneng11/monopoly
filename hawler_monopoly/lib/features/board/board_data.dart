import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/board_tile.dart';

class TileData {
  final String name;
  final TileType type;
  final Color? groupColor;
  final int? price;
  final IconData? icon;
  final bool owned;
  final Color? ownerColor;

  const TileData({
    required this.name,
    this.type = TileType.property,
    this.groupColor,
    this.price,
    this.icon,
    this.owned = false,
    this.ownerColor,
  });
}

/// ٤٠ خانەی تەختەکە — ناوی گەڕەک و شوێنە مێژووییەکانی هەولێر.
List<TileData> buildBoardTiles() {
  final g = AppColors.propertyGroups;
  return [
    const TileData(name: 'بەرەو دەستپێک', type: TileType.corner, icon: Icons.flag_circle),
    TileData(name: 'گەڕەکی قەڵات', price: 60, groupColor: g[0], owned: true, ownerColor: AppColors.emerald),
    const TileData(name: 'چانس', type: TileType.chance, icon: Icons.help_outline),
    TileData(name: 'گەڕەکی شۆڕش', price: 60, groupColor: g[0]),
    const TileData(name: 'باجی موڵک', type: TileType.tax, icon: Icons.receipt_long),
    TileData(name: 'گاراجی شار', type: TileType.station, price: 200, icon: FontAwesomeIcons.trainSubway),
    TileData(name: 'بازاڕی قەیسەری', price: 100, groupColor: g[1], owned: true, ownerColor: AppColors.sapphire),
    const TileData(name: 'ڕووداو', type: TileType.event, icon: Icons.auto_awesome),
    TileData(name: 'گەڕەکی برایەتی', price: 100, groupColor: g[1]),
    TileData(name: 'گەڕەکی سەرچنار', price: 120, groupColor: g[1]),
    const TileData(name: 'زیندان', type: TileType.corner, icon: Icons.gavel),
    TileData(name: 'پارکی شانەدەر', price: 140, groupColor: g[2]),
    TileData(name: 'کارەبای شار', type: TileType.station, price: 150, icon: Icons.bolt),
    TileData(name: 'گەڕەکی ئازادی', price: 140, groupColor: g[2]),
    TileData(name: 'گەڕەکی سەلاحەدین', price: 160, groupColor: g[2]),
    TileData(name: 'گاراجی باشوور', type: TileType.station, price: 200, icon: FontAwesomeIcons.trainSubway),
    TileData(name: 'گەڕەکی نەورۆز', price: 180, groupColor: g[3]),
    const TileData(name: 'چانس', type: TileType.chance, icon: Icons.help_outline),
    TileData(name: 'گەڕەکی خانزاد', price: 180, groupColor: g[3]),
    TileData(name: 'گەڕەکی کوردستان', price: 200, groupColor: g[3]),
    const TileData(name: 'پارکینگی خۆڕایی', type: TileType.corner, icon: Icons.local_parking),
    TileData(name: 'گەڕەکی گوندی زانیاری', price: 220, groupColor: g[4]),
    const TileData(name: 'ڕووداو', type: TileType.event, icon: Icons.auto_awesome),
    TileData(name: 'گەڕەکی ئاشتی', price: 220, groupColor: g[4]),
    TileData(name: 'گەڕەکی زانکۆ', price: 240, groupColor: g[4]),
    TileData(name: 'گاراجی ڕۆژهەڵات', type: TileType.station, price: 200, icon: FontAwesomeIcons.trainSubway),
    TileData(name: 'گەڕەکی شاری زانا', price: 260, groupColor: g[5]),
    TileData(name: 'گەڕەکی گەلی کورد', price: 260, groupColor: g[5]),
    TileData(name: 'ئاوی شار', type: TileType.station, price: 150, icon: Icons.water_drop),
    TileData(name: 'گەڕەکی هەڵگورد', price: 280, groupColor: g[5]),
    const TileData(name: 'بنێرە زیندان', type: TileType.corner, icon: Icons.local_police),
    TileData(name: 'گەڕەکی نیشتمان', price: 300, groupColor: g[6]),
    TileData(name: 'گەڕەکی ڕۆشنبیری', price: 300, groupColor: g[6]),
    const TileData(name: 'چانس', type: TileType.chance, icon: Icons.help_outline),
    TileData(name: 'گەڕەکی گەشتیاری', price: 320, groupColor: g[6]),
    TileData(name: 'گاراجی باکوور', type: TileType.station, price: 200, icon: FontAwesomeIcons.trainSubway),
    const TileData(name: 'ڕووداو', type: TileType.event, icon: Icons.auto_awesome),
    TileData(name: 'گەڕەکی شاهانی', price: 350, groupColor: g[7]),
    const TileData(name: 'باجی شکۆداری', type: TileType.tax, icon: Icons.receipt_long),
    TileData(name: 'قوللەی هەولێر', price: 400, groupColor: g[7], icon: Icons.location_city),
  ];
}
