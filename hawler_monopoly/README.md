# مۆنۆپۆلی هەولێر — Hawler Monopoly (UI Only)

A pixel-crafted, Material 3 Flutter **UI-only** implementation of a Monopoly-style
game themed around Hawler (Erbil) and Kurdish culture. Every visible string is in
**Kurdish Sorani**, laid out **RTL**.

> ⚠️ This package intentionally contains **no game logic, backend, or multiplayer
> code**. State shown on screens (cash, positions, dice results, etc.) is local
> `setState` demo data so the UI can be previewed and animated. Wire it up to your
> own game engine / bloc / riverpod / backend of choice.

## Getting started

```bash
flutter pub get
flutter run
```

Minimum Flutter SDK: 3.3+ (Material 3, `Switch.adaptive`-free API used).

### Fonts

The UI uses `google_fonts` (`Noto Kufi Arabic`) which renders Kurdish Sorani
correctly out of the box and downloads on first run. If you want a fully
offline/bundled font, drop your `.ttf` files into `assets/fonts/` and uncomment
the `fonts:` section in `pubspec.yaml`.

## Folder structure (Clean Architecture, UI layer)

```
lib/
  main.dart                       # App root, RTL wrapper, theme wiring
  core/
    theme/
      app_colors.dart             # Luxury palette + gradients + shadows
      app_text_styles.dart        # Kurdish-friendly typography scale
      app_theme.dart              # Material 3 ThemeData
    widgets/                      # Reusable, screen-agnostic widgets
      luxury_background.dart      # Gradient bg + citadel silhouette
      glass_container.dart        # Glassmorphism primitive
      golden_button.dart          # Animated gradient CTA button
      animated_dice.dart          # 3D-style rolling dice
      common_widgets.dart         # CurrencyPill, AvatarRing, SectionHeader...
      widgets.dart                # Barrel export
  features/
    splash/        splash_screen.dart
    auth/           login_screen.dart
    home/           home_screen.dart              # Hub + bottom nav
    lobby/          lobby_screen.dart              # Room list / create / join
    board/
      board_screen.dart                            # 11x11 perimeter board
      board_data.dart                               # 40-tile Kurdish dataset
      widgets/board_tile.dart
      widgets/player_token.dart
    player/         player_info_widget.dart         # In-game player HUD
    property/
      property_card.dart
      buy_property_dialog.dart
      upgrade_dialog.dart
    cards/
      chance_card.dart                              # Chance + Event share logic
      event_card.dart
    winner/         winner_screen.dart               # Confetti celebration
    leaderboard/    leaderboard_screen.dart          # Podium + ranked list
    profile/        profile_screen.dart
    shop/           shop_screen.dart                 # Coin packs + cosmetics
    inventory/      inventory_screen.dart
    settings/       settings_screen.dart
    rewards/        daily_rewards_screen.dart        # 7-day streak
    achievements/   achievements_screen.dart
```

## Design language

- **Palette**: citadel browns/terracotta (Erbil Citadel), gold accents, emerald
  & sapphire jewel tones, deep night background.
- **Glassmorphism** everywhere via `GlassContainer` (blur + translucent fill +
  soft border).
- **Premium gradients** on CTAs and header cards (`AppColors.goldGradient`,
  `citadelCard`, `duskSky`).
- **Soft shadows / gold glow** helpers (`AppColors.softShadow`, `goldGlow`).
- **Motion**: `animate_do` micro-entrances (FadeInUp/ZoomIn), custom
  `AnimatedDice` roll, `AnimatedPositioned` token movement, `confetti` on the
  winner screen — all tuned for 60fps (implicit animations, no heavy rebuilds).

## Wiring this into a real game

Every screen is a `StatefulWidget` with local, clearly-marked placeholder state
(see `board_screen.dart`'s `tokenPosition`/`diceResult`, `player_info_widget.dart`'s
`_players` list). Swap these for your state-management solution — the widgets
themselves (`BoardTile`, `PlayerToken`, `PropertyCard`, dialogs) are already pure
and reusable, taking data in via constructor parameters.
