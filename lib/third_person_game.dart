import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(const HighwayRush3DApp());
}

class HighwayRush3DApp extends StatelessWidget {
  const HighwayRush3DApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Highway Rush 3D',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF07111D),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFB52E), brightness: Brightness.dark),
    ),
    home: const ChaseRaceScreen(),
  );
}

class ChaseRaceScreen extends StatefulWidget {
  const ChaseRaceScreen({super.key});
  @override
  State<ChaseRaceScreen> createState() => _ChaseRaceScreenState();
}

class _ChaseRaceScreenState extends State<ChaseRaceScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final _random = math.Random();
  double _distance = 0, _speed = 0.55, _lane = 0, _targetLane = 0, _nitro = 1;
  int _coins = 0, _best = 0, _carLevel = 1;
  bool _running = true, _nitroOn = false, _showGarage = false;
  double _time = 0;
  final List<_RoadItem> _items = [];
  static const _gold = Color(0xFFFFB52E);

  @override
  void initState() {
    super.initState();
    _loadBest();
    for (int i = 0; i < 14; i++) {
      _items.add(_RoadItem(z: i / 14, lane: _random.nextInt(3) - 1, kind: i % 4 == 0 ? 1 : 0));
    }
    _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_tick)
      ..repeat();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _best = prefs.getInt('highway_rush_3d_best') ?? 0);
  }

  void _tick() {
    if (!_running || _showGarage) return;
    final dt = 1 / 60;
    _time += dt;
    _speed += ((_nitroOn && _nitro > 0) ? .0015 : .00035);
    _speed = _speed.clamp(.45, _nitroOn ? 1.25 : .88);
    if (_nitroOn && _nitro > 0) _nitro = (_nitro - dt * .18).clamp(0, 1);
    else _nitro = (_nitro + dt * .035).clamp(0, 1);
    _lane += (_targetLane - _lane) * .16;
    _distance += _speed * dt * 28;
    for (final item in _items) {
      item.z += dt * (_speed * .27);
      if (item.z > 1.04) {
        item.z = -.05;
        item.lane = _random.nextInt(3) - 1;
        item.kind = _random.nextInt(5) == 0 ? 1 : 0;
      }
      if (!item.collected && item.z > .83 && item.z < .91 && (item.lane - _lane).abs() < .43) {
        if (item.kind == 1) {
          _finishRace();
          return;
        }
        item.collected = true;
        _coins++;
      }
      if (item.z > .97) item.collected = false;
    }
    if (mounted) setState(() {});
  }

  void _finishRace() {
    _running = false;
    final meters = _distance.floor();
    if (meters > _best) {
      _best = meters;
      SharedPreferences.getInstance().then((p) => p.setInt('highway_rush_3d_best', _best));
    }
    setState(() {});
  }

  void _restart() {
    setState(() {
      _distance = 0; _coins = 0; _speed = .55; _lane = 0; _targetLane = 0;
      _nitro = 1; _nitroOn = false; _running = true; _time = 0;
      for (final item in _items) {
        item.z = _random.nextDouble() * .85;
        item.lane = _random.nextInt(3) - 1;
        item.kind = _random.nextInt(5) == 0 ? 1 : 0;
        item.collected = false;
      }
    });
  }

  @override
  void dispose() { _ticker.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _ChasePainter(items: _items, lane: _lane, speed: _speed, time: _time, carLevel: _carLevel)),
        SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), child: Row(children: [
            _hud('DISTANCE', '${_distance.floor()} m', Icons.route_rounded),
            const SizedBox(width: 7),
            _hud('COINS', '$_coins', Icons.monetization_on_rounded),
            const SizedBox(width: 7),
            _hud('BEST', '$_best m', Icons.emoji_events_rounded),
          ])),
          const Spacer(),
          if (_showGarage) _garagePanel(),
          if (!_running) _gameOverPanel(),
          if (_running && !_showGarage) Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _control(Icons.arrow_left_rounded, 'LEFT', () => setState(() => _targetLane = (_targetLane - 1).clamp(-1, 1).toDouble())),
              const Spacer(),
              GestureDetector(
                onTapDown: (_) => setState(() => _nitroOn = true),
                onTapUp: (_) => setState(() => _nitroOn = false),
                onTapCancel: () => setState(() => _nitroOn = false),
                child: Container(width: 76, height: 76, decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFFFD56A), Color(0xFFFF7900)]),
                  boxShadow: [BoxShadow(color: _gold.withOpacity(.35), blurRadius: 18)],
                  border: Border.all(color: Colors.white.withOpacity(.65), width: 2),
                ), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF351600), size: 30),
                  Text('NITRO ${(_nitro * 100).round()}%', style: const TextStyle(color: Color(0xFF351600), fontWeight: FontWeight.w900, fontSize: 9)),
                ])),
              ),
              const Spacer(),
              _control(Icons.arrow_right_rounded, 'RIGHT', () => setState(() => _targetLane = (_targetLane + 1).clamp(-1, 1).toDouble())),
            ]),
          ),
          if (_running && !_showGarage) Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('SWIPE LEFT / RIGHT TO CHANGE LANES', style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
          ),
        ])),
        if (_running && !_showGarage) Positioned.fill(child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 100) setState(() => _targetLane = (_targetLane + (v < 0 ? -1 : 1)).clamp(-1, 1).toDouble());
          },
          child: const SizedBox.expand(),
        )),
        Positioned(top: MediaQuery.paddingOf(context).top + 68, right: 12, child: IconButton.filledTonal(
          onPressed: () => setState(() => _showGarage = !_showGarage),
          icon: Icon(_showGarage ? Icons.close : Icons.garage_rounded),
          tooltip: 'Garage',
        )),
      ]),
    );
  }

  Widget _hud(String title, String value, IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: const Color(0xE809192B), borderRadius: BorderRadius.circular(15), border: Border.all(color: _gold.withOpacity(.65)), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)]),
    child: Column(children: [
      Icon(icon, color: _gold, size: 18),
      Text(title, style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: .7)),
      FittedBox(child: Text(value, style: const TextStyle(fontSize: 17, color: _gold, fontWeight: FontWeight.w900))),
    ]),
  ));

  Widget _control(IconData icon, String label, VoidCallback action) => Column(children: [
    Material(color: const Color(0xCC0A1C2F), shape: const CircleBorder(side: BorderSide(color: _gold, width: 1.5)), child: InkWell(customBorder: const CircleBorder(), onTap: action, child: SizedBox(width: 62, height: 62, child: Icon(icon, color: Colors.white, size: 36)))),
    const SizedBox(height: 5),
    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
  ]);

  Widget _gameOverPanel() => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 70),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: const Color(0xF20A1725), borderRadius: BorderRadius.circular(25), border: Border.all(color: _gold, width: 1.5), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 22)]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.flag_rounded, color: _gold, size: 44),
      const Text('RACE OVER', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
      const SizedBox(height: 8),
      Text('Distance: ${_distance.floor()} m  •  Coins: $_coins', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: const Color(0xFF271600), padding: const EdgeInsets.symmetric(vertical: 15)), onPressed: _restart, icon: const Icon(Icons.replay_rounded), label: const Text('RACE AGAIN', style: TextStyle(fontWeight: FontWeight.w900)) ),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => setState(() => _showGarage = true), icon: const Icon(Icons.garage_rounded), label: const Text('GARAGE / UPGRADES')),
    ]),
  );

  Widget _garagePanel() => Container(
    margin: const EdgeInsets.fromLTRB(18, 0, 18, 80),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: const Color(0xF20A1725), borderRadius: BorderRadius.circular(24), border: Border.all(color: _gold, width: 1.5)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.garage_rounded, color: _gold, size: 38),
      const Text('RACING GARAGE', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
      Text('Car level $_carLevel  •  Coins $_coins', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 12),
      const Text('Upgrade engine to increase your starting speed.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: _coins >= _carLevel * 10 ? () => setState(() { _coins -= _carLevel * 10; _carLevel++; }) : null, child: Text('UPGRADE ENGINE • ${_carLevel * 10} COINS'))),
      TextButton(onPressed: () => setState(() => _showGarage = false), child: const Text('BACK TO RACE')),
    ]),
  );
}

class _RoadItem {
  double z;
  int lane;
  int kind;
  bool collected = false;
  _RoadItem({required this.z, required this.lane, required this.kind});
}

class _ChasePainter extends CustomPainter {
  final List<_RoadItem> items;
  final double lane, speed, time;
  final int carLevel;
  _ChasePainter({required this.items, required this.lane, required this.speed, required this.time, required this.carLevel});

  static const _gold = Color(0xFFFFB52E);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()..isAntiAlias = true;
    p.shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1676C9), Color(0xFF80C9F5), Color(0xFFDBF1FF)]).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, p); p.shader = null;
    // Distant mountain range.
    final mountains = Path()..moveTo(0, h * .52);
    for (int i = 0; i < 11; i++) {
      final x = w * i / 10;
      mountains.lineTo(x, h * (.34 + .09 * math.sin(i * 2.1 + .4)));
      mountains.lineTo(x + w * .055, h * .51);
    }
    mountains..lineTo(w, h * .56)..lineTo(0, h * .56)..close();
    p.color = const Color(0xFF5D8498); canvas.drawPath(mountains, p);
    p.color = const Color(0xFF4F9154); canvas.drawRect(Rect.fromLTWH(0, h * .52, w, h * .48), p);
    // Road trapezoid converges to a vanishing point for chase-camera perspective.
    final vanX = w * (.5 + lane * .015), vanY = h * .34;
    final road = Path()..moveTo(vanX - w * .035, vanY)..lineTo(vanX + w * .035, vanY)..lineTo(w * 1.03, h)..lineTo(-w * .03, h)..close();
    p.shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF697783), Color(0xFF293542), Color(0xFF111A24)]).createShader(Rect.fromLTWH(0, vanY, w, h - vanY));
    canvas.drawPath(road, p); p.shader = null;
    // Road edges and dashed lane markers move towards the camera.
    p.color = _gold; p.strokeWidth = 3;
    canvas.drawLine(Offset(vanX - w * .035, vanY), Offset(-w * .02, h), p);
    canvas.drawLine(Offset(vanX + w * .035, vanY), Offset(w * 1.02, h), p);
    for (int laneIndex = 1; laneIndex <= 2; laneIndex++) {
      final bottomX = w * laneIndex / 3;
      final topX = vanX + (laneIndex - 1) * w * .035;
      for (int j = 0; j < 12; j++) {
        final t = ((j / 12 + time * speed * .35) % 1).toDouble();
        final y = vanY + (h - vanY) * t * t;
        final x = topX + (bottomX - topX) * t;
        final dashH = 2 + 18 * t;
        p.color = Colors.white.withOpacity(.9); p.strokeWidth = 1 + 3 * t;
        canvas.drawLine(Offset(x, y), Offset(x, y + dashH), p);
      }
    }
    // Roadside trees scale with perspective.
    for (int i = 0; i < 9; i++) {
      final t = ((i / 9 + time * .11) % 1).toDouble();
      final y = vanY + (h - vanY) * t * t;
      final scale = .08 + t * .78;
      for (final side in [-1, 1]) {
        final x = vanX + side * (w * .05 + t * w * .6);
        p.color = const Color(0xFF5A3D2A);
        canvas.drawRect(Rect.fromCenter(center: Offset(x, y - 18 * scale), width: 5 * scale, height: 28 * scale), p);
        p.color = side == -1 ? const Color(0xFF176A43) : const Color(0xFF247B49);
        final tree = Path()..moveTo(x, y - 70 * scale)..lineTo(x - 26 * scale, y - 8 * scale)..lineTo(x + 26 * scale, y - 8 * scale)..close();
        canvas.drawPath(tree, p);
      }
    }
    // Coins and traffic objects are projected from the horizon to the foreground.
    for (final item in items) {
      if (item.collected) continue;
      final t = item.z.clamp(0, 1).toDouble();
      final y = vanY + (h - vanY) * t * t * .87;
      final centerRoadX = vanX + (w * (item.lane + 1) / 3 - w * .5) * t * 1.75;
      final scale = .12 + t * 1.2;
      if (item.kind == 1) {
        final rect = Rect.fromCenter(center: Offset(centerRoadX, y - 20 * scale), width: 42 * scale, height: 64 * scale);
        p.color = const Color(0xFF176DC1); canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(6 * scale),), p);
        p.color = const Color(0xFF9DE0FF);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(rect.left + 5 * scale, rect.top + 6 * scale, rect.width - 10 * scale, rect.height * .28), Radius.circular(3 * scale)), p);
        p.color = const Color(0xFFFF4E45);
        canvas.drawRect(Rect.fromLTWH(rect.left + 4 * scale, rect.bottom - 9 * scale, 7 * scale, 4 * scale), p);
        canvas.drawRect(Rect.fromLTWH(rect.right - 11 * scale, rect.bottom - 9 * scale, 7 * scale, 4 * scale), p);
      } else {
        p.color = const Color(0xFFFFB000); canvas.drawCircle(Offset(centerRoadX, y - 20 * scale), 10 * scale, p);
        p.color = const Color(0xFFFFF0A6); p.style = PaintingStyle.stroke; p.strokeWidth = 2 * scale;
        canvas.drawCircle(Offset(centerRoadX, y - 20 * scale), 6 * scale, p); p.style = PaintingStyle.fill;
      }
    }
    _drawPlayerCar(canvas, size, lane, carLevel, p);
    // Subtle motion streaks when nitro/speed increases.
    if (speed > .8) {
      p.color = const Color(0x66FFFFFF); p.strokeWidth = 2;
      for (int i = 0; i < 10; i++) {
        final x = w * (i + 1) / 11;
        canvas.drawLine(Offset(x, h * (.66 + (i % 3) * .05)), Offset(x, h * (.76 + (i % 3) * .06)), p);
      }
    }
  }

  void _drawPlayerCar(Canvas canvas, Size size, double lane, int level, Paint p) {
    final w = size.width, h = size.height;
    final x = w * (.5 + lane * .22), y = h * .82;
    final scale = w / 390;
    canvas.save(); canvas.translate(x, y); canvas.scale(scale);
    p.color = const Color(0x55000000); canvas.drawOval(Rect.fromCenter(center: const Offset(0, 30), width: 130, height: 28), p);
    // Tires.
    p.color = const Color(0xFF101318);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-54, -13, 18, 49), const Radius.circular(6)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(36, -13, 18, 49), const Radius.circular(6)), p);
    // Rear body in layered polygonal panels.
    final body = Path()..moveTo(-55, 15)..lineTo(-48, -27)..lineTo(-31, -53)..lineTo(31, -53)..lineTo(48, -27)..lineTo(55, 15)..lineTo(39, 29)..lineTo(-39, 29)..close();
    p.shader = const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFF9E101A), Color(0xFFFF3039), Color(0xFFB70D1A)]).createShader(const Rect.fromLTWH(-55, -53, 110, 82));
    canvas.drawPath(body, p); p.shader = null;
    final rearGlass = Path()..moveTo(-29, -44)..lineTo(29, -44)..lineTo(39, -24)..lineTo(-39, -24)..close();
    p.color = const Color(0xFF102A40); canvas.drawPath(rearGlass, p);
    p.color = const Color(0xFF86DFFF); p.strokeWidth = 2;
    canvas.drawLine(const Offset(-26, -41), const Offset(0, -41), p);
    // Spoiler and tail lights.
    p.color = const Color(0xFF222831); canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-49, -14, 98, 7), const Radius.circular(3)), p);
    p.color = const Color(0xFFFF3333);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-43, 0, 18, 7), const Radius.circular(3)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(25, 0, 18, 7), const Radius.circular(3)), p);
    p.color = const Color(0xFFFFC94D); canvas.drawRect(const Rect.fromLTWH(-13, 12, 26, 8), p);
    if (level > 1) {
      p.color = _gold; canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-24, 22, 48, 4), const Radius.circular(2)), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChasePainter old) => true;
}
