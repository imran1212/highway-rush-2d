# Highway Rush 2D

A first playable side-view arcade racing prototype made with Flutter + Flame.

## Features
- Portrait-oriented Android game
- Custom-drawn scenery and car; no external image assets required
- Hold GAS to accelerate, BRAKE to slow down, tap JUMP to jump
- Lightweight gravity/jump physics and terrain following
- Coin collection, obstacles, distance score and saved best score
- Restart after game over

## Run
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## GitHub + Codemagic
The `highway-rush-android-test` workflow creates the Android platform scaffold if missing, analyzes and tests the project, and produces a debug APK. Run the release workflow only after configuring an Android upload keystore in Codemagic.

## Notes
This is a prototype. Ads, in-app purchases, consent, analytics, production privacy policy, and device testing are not included yet. Physics are lightweight arcade-style, not a full rigid-body simulation.
