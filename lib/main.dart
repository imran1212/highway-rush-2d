import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(const HighwayRushApp());
}

class HighwayRushApp extends StatelessWidget {
  const HighwayRushApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Highway Rush 2D',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF101820),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFB000),
            brightness: Brightness.dark,
          ),
        ),
        home: const RacingScreen(),
      );
}

class RacingScreen extends StatefulWidget {
  const RacingScreen({super.key});

  @override
  State<RacingScreen> createState() => _RacingScreenState();
}

class _RacingScreenState extends State<RacingScreen> {
  late final HighwayRushGame game;

  @override
  void initState() {
    super.initState();
    game = HighwayRushGame();
  }

  @override
  void dispose() {
    game.disposeNotifiers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget<HighwayRushGame>(game: game),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 12,
              right: 12,
              child: ValueListenableBuilder<GameHud>(
                valueListenable: game.hud,
                builder: (_, hud, __) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Stat(label: 'DISTANCE', value: '${hud.distanceMeters} m'),
                    _Stat(label: 'COINS', value: '${hud.coins}'),
                    _Stat(label: 'BEST', value: '${hud.bestMeters} m'),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              child: ValueListenableBuilder<GameHud>(
                valueListenable: game.hud,
                builder: (_, hud, __) {
                  if (hud.gameOver) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xF2182029),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFFFB000)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('RACE OVER',
                              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text('Distance: ${hud.distanceMeters} m   •   Coins: ${hud.coins}'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: game.restart,
                            child: const Text('RACE AGAIN'),
                          ),
                        ],
                      ),
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Control(
                        label: 'BRAKE',
                        icon: Icons.remove_rounded,
                        color: const Color(0xFFEF5350),
                        onDown: () => game.setBraking(true),
                        onUp: () => game.setBraking(false),
                      ),
                      _Control(
                        label: 'JUMP',
                        icon: Icons.north_rounded,
                        color: const Color(0xFF42A5F5),
                        onDown: game.jump,
                        onUp: () {},
                      ),
                      _Control(
                        label: 'GAS',
                        icon: Icons.speed_rounded,
                        color: const Color(0xFFFFB000),
                        onDown: () => game.setAccelerating(true),
                        onUp: () => game.setAccelerating(false),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xDD101820),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70, letterSpacing: 1)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.icon,
    required this.color,
    required this.onDown,
    required this.onUp,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => onDown(),
        onTapUp: (_) => onUp(),
        onTapCancel: onUp,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: Colors.white70),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF101820), size: 28),
              Text(label, style: const TextStyle(color: Color(0xFF101820), fontWeight: FontWeight.w900, fontSize: 10)),
            ],
          ),
        ),
      );
}

class GameHud {
  const GameHud({
    required this.distanceMeters,
    required this.coins,
    required this.bestMeters,
    required this.gameOver,
    required this.startedSeconds,
  });

  final int distanceMeters;
  final int coins;
  final int bestMeters;
  final bool gameOver;
  final double startedSeconds;
}

/// Lightweight arcade physics: gravity/jump, terrain following and collisions.
class HighwayRushGame extends FlameGame {
  HighwayRushGame() {
    hud = ValueNotifier<GameHud>(const GameHud(
      distanceMeters: 0,
      coins: 0,
      bestMeters: 0,
      gameOver: false,
      startedSeconds: 0,
    ));
    _loadBest();
  }

  late final ValueNotifier<GameHud> hud;
  static const double _baseSpeed = 175;
  static const double _maxSpeed = 390;
  static const double _gravity = 1250;
  static const double _jumpImpulse = -475;
  static const double _carWidth = 82;
  static const double _carHeight = 32;
  static const double _wheelRadius = 10;

  final Paint _p = Paint()..isAntiAlias = true;
  final List<double> _obstacles = List.generate(60, (i) => 780 + i * 570.0);
  final List<double> _coinXs = List.generate(150, (i) => 360 + i * 215.0);
  final Set<int> _collected = {};
  final Set<int> _passed = {};

  double _w = 400, _h = 800, _distance = 0, _speed = _baseSpeed;
  double _carY = 0, _vy = 0, _rotation = 0, _elapsed = 0, _hudTimer = 0;
  int _coins = 0, _best = 0;
  bool _gas = false, _brake = false, _grounded = true, _over = false;

  double get _carX => _w * .25;
  double get _groundBase => _h * .755;

  double _terrain(double x) =>
      _groundBase + math.sin(x * .0065) * 17 + math.sin(x * .015) * 6;

  double _groundCarY(double x) => _terrain(x) - _wheelRadius - _carHeight * .36;

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _best = prefs.getInt('highway_rush_best_meters') ?? 0;
      _publish();
    } catch (_) {}
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _w = size.x;
    _h = size.y;
    if (_carY == 0) _carY = _groundCarY(_distance + _carX);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_over || _w <= 0 || _h <= 0) return;
    final step = dt.clamp(0.0, .04).toDouble();
    _elapsed += step;
    if (_gas) {
      _speed = (_speed + 260 * step).clamp(_baseSpeed, _maxSpeed).toDouble();
    } else {
      _speed = (_speed - 80 * step).clamp(_baseSpeed, _maxSpeed).toDouble();
    }
    if (_brake) _speed = (_speed - 360 * step).clamp(85.0, _maxSpeed).toDouble();

    _distance += _speed * step;
    final worldX = _distance + _carX;
    final groundY = _groundCarY(worldX);
    if (!_grounded) {
      _vy += _gravity * step;
      _carY += _vy * step;
      if (_carY >= groundY) {
        _carY = groundY;
        _vy = 0;
        _grounded = true;
      }
    } else {
      _carY = groundY;
    }
    _rotation = _grounded
        ? math.atan2(_terrain(worldX + 18) - _terrain(worldX - 18), 36)
        : (_vy * .00018).clamp(-.22, .22).toDouble();

    _checkCoins(worldX);
    _checkObstacles(worldX);
    _hudTimer += step;
    if (_hudTimer >= .12) {
      _hudTimer = 0;
      _publish();
    }
  }

  void setAccelerating(bool value) => _gas = value && !_over;
  void setBraking(bool value) => _brake = value && !_over;

  void jump() {
    if (!_over && _grounded) {
      _grounded = false;
      _vy = _jumpImpulse;
    }
  }

  void restart() {
    _distance = 0;
    _speed = _baseSpeed;
    _vy = 0;
    _rotation = 0;
    _elapsed = 0;
    _coins = 0;
    _over = false;
    _grounded = true;
    _gas = false;
    _brake = false;
    _collected.clear();
    _passed.clear();
    _carY = _groundCarY(_carX);
    _publish();
  }

  void _checkCoins(double playerX) {
    for (var i = 0; i < _coinXs.length; i++) {
      if (_collected.contains(i) || (_coinXs[i] - playerX).abs() >= 35) continue;
      final coinY = _terrain(_coinXs[i]) - 66;
      if ((_carY - coinY).abs() < 88) {
        _collected.add(i);
        _coins++;
      }
    }
  }

  void _checkObstacles(double playerX) {
    for (var i = 0; i < _obstacles.length; i++) {
      if (_passed.contains(i) || (_obstacles[i] - playerX).abs() >= _carWidth * .48 + 15) continue;
      final groundY = _terrain(_obstacles[i]);
      final above = _carY < groundY - 55;
      if (!above && _carY + _carHeight * .35 >= groundY - 30) {
        _endGame();
        return;
      }
      _passed.add(i);
    }
  }

  void _endGame() {
    _over = true;
    _gas = false;
    _brake = false;
    final meters = (_distance / 10).floor();
    if (meters > _best) {
      _best = meters;
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setInt('highway_rush_best_meters', _best),
      ).catchError((_) {});
    }
    _publish();
  }

  void _publish() {
    hud.value = GameHud(
      distanceMeters: (_distance / 10).floor(),
      coins: _coins,
      bestMeters: _best,
      gameOver: _over,
      startedSeconds: _elapsed,
    );
  }

  void disposeNotifiers() => hud.dispose();

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_w <= 0 || _h <= 0) return;

    _p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF64C8F0), Color(0xFFC8F2FF), Color(0xFFFFD69A)],
    ).createShader(Rect.fromLTWH(0, 0, _w, _h));
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), _p);
    _p.shader = null;

    _p.color = const Color(0xFFFFF1A8);
    canvas.drawCircle(Offset(_w * .78, _h * .17), 29, _p);
    _drawHills(canvas);

    final ground = Path()..moveTo(0, _h);
    for (double x = 0; x <= _w + 8; x += 8) {
      ground.lineTo(x, _terrain(x + _distance));
    }
    ground..lineTo(_w, _h)..close();
    _p.color = const Color(0xFF4D9B50);
    canvas.drawPath(ground, _p);

    final edge = Path();
    for (double x = 0; x <= _w + 8; x += 8) {
      final y = _terrain(x + _distance);
      if (x == 0) {
        edge.moveTo(x, y);
      } else {
        edge.lineTo(x, y);
      }
    }
    _p..color = const Color(0xFFDFE6E9)..strokeWidth = 5..style = PaintingStyle.stroke;
    canvas.drawPath(edge, _p);
    _p.style = PaintingStyle.fill;

    _drawCoins(canvas);
    _drawObstacles(canvas);
    _drawCar(canvas);
    if (_over) {
      _p.color = const Color(0x55000000);
      canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), _p);
    }
  }

  void _drawHills(Canvas canvas) {
    final path = Path()..moveTo(0, _h * .65);
    for (double x = 0; x <= _w + 8; x += 8) {
      path.lineTo(x, _h * .57 + math.sin((x + _distance * .12) * .008) * 24);
    }
    path..lineTo(_w, _h)..lineTo(0, _h)..close();
    _p.color = const Color(0xFF8DCB8D);
    canvas.drawPath(path, _p);
  }

  void _drawCoins(Canvas canvas) {
    for (var i = 0; i < _coinXs.length; i++) {
      if (_collected.contains(i)) continue;
      final x = _coinXs[i] - _distance;
      if (x < -30 || x > _w + 30) continue;
      final y = _terrain(_coinXs[i]) - 66;
      _p.color = const Color(0xFFFFB000);
      canvas.drawCircle(Offset(x, y), 11, _p);
      _p..color = const Color(0xFFFFF1A8)..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), 6, _p);
      _p.style = PaintingStyle.fill;
    }
  }

  void _drawObstacles(Canvas canvas) {
    for (var i = 0; i < _obstacles.length; i++) {
      if (_passed.contains(i)) continue;
      final x = _obstacles[i] - _distance;
      if (x < -40 || x > _w + 40) continue;
      final y = _terrain(_obstacles[i]);
      final rock = Path()
        ..moveTo(x - 15, y)..lineTo(x - 7, y - 25)
        ..lineTo(x + 9, y - 29)..lineTo(x + 18, y)..close();
      _p.color = const Color(0xFF795548);
      canvas.drawPath(rock, _p);
    }
  }

  void _drawCar(Canvas canvas) {
    canvas.save();
    canvas.translate(_carX, _carY);
    canvas.rotate(_rotation);

    _p.color = const Color(0x33000000);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 22), width: 92, height: 12), _p);

    _p.color = const Color(0xFF9B1C24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-39, -13, 10, 22), const Radius.circular(3)),
      _p,
    );
    final body = Path()
      ..moveTo(-42, 5)..lineTo(-35, -9)
      ..quadraticBezierTo(-27, -18, -11, -18)
      ..lineTo(15, -18)..quadraticBezierTo(27, -17, 34, -6)
      ..lineTo(43, 2)..lineTo(41, 10)..lineTo(-39, 10)..close();
    _p.color = const Color(0xFFE53935);
    canvas.drawPath(body, _p);

    final glass = Path()
      ..moveTo(-19, -15)..lineTo(11, -15)..lineTo(23, -5)..lineTo(-26, -5)..close();
    _p.color = const Color(0xFFB8E7F7);
    canvas.drawPath(glass, _p);

    _p.color = const Color(0xFFFFF59D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(36, -1, 5, 5), const Radius.circular(2)),
      _p,
    );
    for (final wx in [-25.0, 25.0]) {
      _p.color = const Color(0xFF20252B);
      canvas.drawCircle(Offset(wx, 10), _wheelRadius, _p);
      _p.color = const Color(0xFFB0BEC5);
      canvas.drawCircle(Offset(wx, 10), 4, _p);
    }
    canvas.restore();
  }
}
