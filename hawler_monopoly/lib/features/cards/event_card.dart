import 'package:flutter/material.dart';
import '../../domain/models/game_models.dart';
import 'chance_card.dart';

/// کارتی ڕووداو — بنیاتی هاوبەشی لەگەڵ [GameCardDialog] بەکاردەهێنێت
/// بۆ یەکگرتوویی دیزاین و کۆدی دووبارە نەکراوە.
class EventCard extends StatelessWidget {
  final GameCard card;
  final String playerName;
  final VoidCallback onClose;

  const EventCard({super.key, required this.card, required this.playerName, required this.onClose});

  @override
  Widget build(BuildContext context) =>
      GameCardDialog(card: card, playerName: playerName, onClose: onClose);
}
