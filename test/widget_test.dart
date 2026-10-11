import 'package:flutter_test/flutter_test.dart';
import 'package:highway_rush_2d/main.dart';

void main() {
  test('GameHud carries expected values', () {
    const hud = GameHud(
      distanceMeters: 120,
      coins: 3,
      bestMeters: 200,
      gameOver: false,
      startedSeconds: 2.5,
    );

    expect(hud.distanceMeters, 120);
    expect(hud.coins, 3);
    expect(hud.bestMeters, 200);
    expect(hud.gameOver, isFalse);
    expect(hud.startedSeconds, 2.5);
  });
}
