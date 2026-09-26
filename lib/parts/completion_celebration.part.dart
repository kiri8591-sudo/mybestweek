// V9.12 — Animation de célébration après validation.
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

class _CompletionCelebration extends StatefulWidget {
  const _CompletionCelebration({super.key});

  @override
  State<_CompletionCelebration> createState() => _CompletionCelebrationState();
}

class _CompletionCelebrationState extends State<_CompletionCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final String _emoji;
  late final int _style;
  late final List<String> _sparks;

  static const _celebrations = ['🎉', '✨', '🌟', '🥳', '🧸', '🌿', '👏', '☀️'];
  static const _sparkPool = ['✨', '✦', '·', '🌟', '💫'];

  @override
  void initState() {
    super.initState();
    final random = Random();
    _emoji = _celebrations[random.nextInt(_celebrations.length)];
    _style = random.nextInt(4);
    _sparks = List.generate(4, (_) => _sparkPool[random.nextInt(_sparkPool.length)]);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_controller.value);
        final burst = Curves.easeOut.transform(_controller.value);
        // Le symbole principal reste visible une fois l’animation terminée ;
        // seules les petites étincelles s’effacent progressivement.
        final fade = _controller.value < .18
            ? (_controller.value / .18).clamp(0.0, 1.0)
            : 1.0;
        final sparkFade = _controller.value < .55
            ? (_controller.value / .55).clamp(0.0, 1.0)
            : ((1 - _controller.value) / .45).clamp(0.0, 1.0);
        final scale = .35 + (.95 * t);
        final angle = (_style.isEven ? 1 : -1) *
            (1 - Curves.easeOut.transform(_controller.value)) * .28;
        final spread = 13 + 18 * burst;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < _sparks.length; i++)
              Positioned(
                left: 16 + [0.0, spread, 12.0, spread - 4][i] - 6,
                top: 16 + [-spread + 4, 0.0, spread - 7, spread * .55][i] - 6,
                child: Opacity(
                  opacity: (sparkFade * .9).clamp(0.0, 1.0).toDouble(),
                  child: Transform.scale(
                    scale: .5 + .65 * burst,
                    child: Text(_sparks[i], style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
            Opacity(
              opacity: fade,
              child: Transform.translate(
                offset: Offset(0, -4 * (1 - burst)),
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale,
                    child: Text(_emoji, style: const TextStyle(fontSize: 30)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
