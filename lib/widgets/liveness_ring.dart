// ─────────────────────────────────────────────────────────────────────────────
//  The circle the face goes in, and the ring that fills as the head turns.
//
//  Built 22 August 2026. Driven by services/liveness_ring_controller.dart —
//  read that file first, it explains why the sweep is ±30 degrees rather than
//  a full rotation.
//
//  ── WHY A RING RATHER THAN A PROGRESS BAR ───────────────────────────────────
//
//  Because the ring IS the head movement. A segment on the left lights when
//  the head is turned left; the shape on screen and the motion of the body
//  are the same shape, so nobody has to be told what the relationship is.
//
//  A bar filling 0 to 100 would carry identical information and teach nothing
//  — the user would still be guessing which way to turn and how far.
//
//  ⚠ THE SEGMENT COUNT LIVES IN THE CONTROLLER, not here. This widget paints
//  whatever length of list it is given. Two constants would drift.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

class LivenessRing extends StatelessWidget {
  const LivenessRing({
    super.key,
    required this.lit,
    this.diameter = 260,
    this.ringColour = const Color(0xFF22C55E),
    // ⚠ RAISED FROM 0x33 TO 0x4D DELIBERATELY, EVEN THOUGH THE TRACK IS NOW
    // QUIETER OVERALL. The stroke dropped from 6px to 3.5px, and a thin line at
    // the old opacity disappears against a bright window or a pale wall — which
    // is exactly the lighting people are told to stand in. Slightly more opaque
    // and much thinner nets out fainter, and survives a real background.
    this.trackColour = const Color(0x4DFFFFFF),
    this.centreActive = false,
  });

  /// One entry per segment, true where the head has already been.
  final List<bool> lit;

  final double diameter;
  final Color ringColour;
  final Color trackColour;

  /// True while the person is being asked to bring their face back to the
  /// middle. Brightens and lengthens the centre mark so there is somewhere
  /// specific to aim at.
  final bool centreActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _RingPainter(
          lit: lit,
          ringColour: ringColour,
          trackColour: trackColour,
          centreActive: centreActive,
        ),
      ),
    );
  }
}

/// Two chevrons under the circle that brighten as each side of the ring fills.
///
/// ── WHAT IT ADDS THAT THE RING DOES NOT ─────────────────────────────────────
///
/// The ring answers "how much have I done". It cannot answer "which way now" —
/// that lives only in the hint text, and text has to be read. On a screen where
/// somebody is concentrating on holding a phone steady and turning their head,
/// reading is the thing they have least attention for.
///
/// A chevron is understood without being read. Dim on one side means "you have
/// not been this way yet"; both bright means the sweep is done.
///
/// ── ⚠ DRIVEN BY THE LIT SEGMENTS, NEVER BY THE HEAD ANGLE ───────────────────
///
/// This is the whole design and it is not a detail.
///
/// The preview is MIRRORED, and ML Kit's sign convention for yaw is not
/// something to guess at. Read the angle directly and there is a fifty percent
/// chance the arrows point opposite to the way the ring is filling — which is
/// disorienting in a way people feel immediately and cannot put into words.
///
/// Taking the same `lit` list the painter uses makes that impossible: the
/// arrows agree with the ring by construction. And if a real device shows the
/// ring itself filling the wrong way round, that is ONE fix in the controller's
/// index mapping and the arrows follow it for free.
///
/// ── NO ANIMATION, DELIBERATELY ──────────────────────────────────────────────
///
/// No pulse, no bounce, no sliding. Movement on a screen that is asking you to
/// hold still reads as urgency, and the point of this is the opposite. Opacity
/// alone is enough, and it is calm.
class LivenessArrows extends StatelessWidget {
  const LivenessArrows({
    super.key,
    required this.lit,
    this.litColour = const Color(0xFF22C55E),
    this.idleColour = Colors.white,
    this.size = 34,
    this.gap = 92,
  });

  /// The same list the ring is painting. See the note above.
  final List<bool> lit;

  final Color litColour;
  final Color idleColour;
  final double size;

  /// Space between the two chevrons. Wide enough that they read as two ends of
  /// a movement rather than as a pair of buttons.
  final double gap;

  static double _fraction(Iterable<bool> half) {
    final List<bool> l = half.toList();
    if (l.isEmpty) return 0;
    return l.where((bool b) => b).length / l.length;
  }

  @override
  Widget build(BuildContext context) {
    final int half = lit.length ~/ 2;

    // ⚠ WHICH HALF BELONGS TO WHICH CHEVRON.
    //
    // The painter starts segment 0 at twelve o'clock and runs CLOCKWISE, so
    // segments 0..half-1 occupy the RIGHT side of the circle and half..end
    // occupy the LEFT. Centre — a head facing forward — sits at the bottom, and
    // the two extremes meet at the top.
    //
    // So the chevron lights on the same side of the screen as the arc that is
    // filling. That is the only relationship that has to hold; see the header
    // for why it is expressed this way and not in degrees.
    final double rightLit = _fraction(lit.take(half));
    final double leftLit = _fraction(lit.skip(half));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _chevron(Icons.chevron_left_rounded, leftLit),
        SizedBox(width: gap),
        _chevron(Icons.chevron_right_rounded, rightLit),
      ],
    );
  }

  Widget _chevron(IconData icon, double filled) => Icon(
        icon,
        size: size,
        // Never fully invisible. A chevron that disappears entirely reads as a
        // rendering fault rather than as "not yet" — 0.3 is present but plainly
        // waiting.
        color: (filled > 0 ? litColour : idleColour)
            .withValues(alpha: 0.30 + 0.70 * filled),
      );
}

/// A radial darkening that fades in from the edges of the preview.
///
/// ── ⚠ WHY A VIGNETTE AND NOT A CIRCULAR CUTOUT ──────────────────────────────
///
/// Chosen 25 August 2026 over a hard-edged spotlight, which is the stronger
/// look. A cutout has to sit EXACTLY over the ring, and the ring is not exactly
/// centred — it shares a column with the direction arrows, so it floats about
/// 26px above the middle. A mask that misses by a few pixels reads as broken
/// rather than deliberate, and this same file runs in four apps on every phone
/// size nobody here owns.
///
/// A gradient has no boundary to misalign. It gets most of the effect and
/// cannot be wrong.
///
/// ⚠ THIS IS PAINT, NOT EXPOSURE. It is drawn over the preview and changes
/// nothing about the frames ML Kit receives — the brightness and glare checks
/// still see the original image. Dimming what the person sees must never dim
/// what the checks measure, or a dark room would start passing.
class LivenessVignette extends StatelessWidget {
  const LivenessVignette({
    super.key,
    this.colour = const Color(0xFF0A1018),
    this.strength = 0.80,
  });

  /// Near-black with a blue cast rather than pure black — pure black against a
  /// camera preview looks like a dead pixel region on OLED.
  final Color colour;

  /// Opacity at the very corners. The centre is always fully clear.
  final double strength;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _VignettePainter(colour: colour, strength: strength),
        ),
      );
}

class _VignettePainter extends CustomPainter {
  _VignettePainter({required this.colour, required this.strength});

  final Color colour;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    // Centred on the face, which sits slightly ABOVE the middle of the preview
    // — the same place the ring is. 0.47 rather than 0.5 for that reason.
    final Offset centre = Offset(size.width / 2, size.height * 0.47);
    final double radius = size.shortestSide * 0.72;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            colour.withValues(alpha: 0),
            colour.withValues(alpha: 0),
            colour.withValues(alpha: strength * 0.52),
            colour.withValues(alpha: strength),
          ],
          // ⚠ THE FIRST STOP IS NOT ZERO. The clear area has to be wide enough
          // to hold the whole ring plus the arrows, or the guide the person is
          // filling sits in the shadow. 0.42 keeps the circle fully lit and
          // starts the fall-off outside it.
          stops: const <double>[0.0, 0.42, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _VignettePainter old) =>
      old.colour != colour || old.strength != strength;
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.lit,
    required this.ringColour,
    required this.trackColour,
    this.centreActive = false,
  });

  final List<bool> lit;
  final Color ringColour;
  final Color trackColour;
  final bool centreActive;

  /// Gap between segments, in radians. Without it the ring reads as one solid
  /// circle and the sense of "filling up piece by piece" is lost.
  static const double _gap = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    if (lit.isEmpty) return;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(10);
    final double sweep = (2 * math.pi) / lit.length;

    // ── ⚠ THE UNLIT TRACK IS QUIETER THAN THE LIT ARC, NOT EQUAL TO IT ───────
    //
    // Reworked 25 August 2026: "it is too simple like new trainee build the UI".
    //
    // The old ring drew both states at almost the same weight — 6px grey
    // against 7px green — so a half-finished sweep read as a grey circle with
    // some green in it rather than as progress. Making the track thinner and
    // fainter than the arc is what turns the same data into something you can
    // judge at a glance from across a room.
    //
    // ⚠ NOTHING HERE CHANGES WHAT THE RING MEANS. Same segments, same list,
    // same completion maths. This is weight and colour only, which is why it
    // was safe to do without retesting the sweep.

    // A continuous hairline under everything, so the circle is a CIRCLE even
    // when nothing is lit. Without it, an empty ring is 24 loose dashes and
    // there is no shape to put your face inside.
    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = trackColour;

    // The halo. A wide, low-opacity pass UNDER the solid stroke — it is what
    // makes the lit part look emitted rather than painted on, and it is the
    // single cheapest thing that separates this from a progress bar bent into
    // a circle. Drawn first so the crisp stroke sits on top of it.
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = ringColour.withValues(alpha: 0.22);

    final Paint on = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = ringColour;

    // ⚠ TWO PASSES, NOT ONE. Every halo is laid down before any solid segment,
    // so a segment's glow cannot paint over its neighbour's crisp edge and
    // leave the arc looking chewed where two lit segments meet.
    for (int i = 0; i < lit.length; i++) {
      if (!lit[i]) continue;
      final double start = -math.pi / 2 + (i * sweep) + (_gap / 2);
      canvas.drawArc(rect, start, sweep - _gap, false, glow);
    }

    for (int i = 0; i < lit.length; i++) {
      // ⚠ STARTS AT THE TOP AND RUNS CLOCKWISE.
      //
      // Canvas angles start at 3 o'clock, so -pi/2 rotates the origin to 12
      // o'clock. Segment 0 is the far LEFT of the head sweep and must appear
      // on the left of the ring — the preview is mirrored, like a mirror, so
      // turning left moves the image left and the ring must agree. Getting
      // this backwards makes the ring fill away from the direction the head
      // is moving, which is disorienting in a way people cannot articulate.
      final double start = -math.pi / 2 + (i * sweep) + (_gap / 2);
      canvas.drawArc(
        rect,
        start,
        sweep - _gap,
        false,
        lit[i] ? on : track,
      );
    }

    _paintCentreMark(canvas, rect);
  }

  /// A short tick at the bottom of the ring, marking dead centre.
  ///
  /// ── ⚠ WHY THE MARK IS AT THE BOTTOM AND NOT THE TOP ─────────────────────
  ///
  /// Because that is where a head facing forward actually sits on this ring.
  /// The painter starts segment 0 at twelve o'clock and runs clockwise, and the
  /// controller maps the two EXTREMES of the sweep to the two ends of that run
  /// — so the extremes meet at the top and centre lands at six o'clock. Putting
  /// the mark anywhere more obvious would be putting it somewhere wrong.
  ///
  /// ── WHY IT EXISTS AT ALL, ADDED 24 August 2026 ───────────────────────────
  ///
  /// Asked for directly after a device test: "give centre line to round, once
  /// both side done with green line and face bring to centre then only auto
  /// selfie trigger".
  ///
  /// The instruction "look straight at the camera" is a description of a
  /// feeling, not a target. People overcorrect past centre and hunt around it,
  /// because nothing on screen says where centre IS. A tick does — and it costs
  /// one line of paint.
  void _paintCentreMark(Canvas canvas, Rect rect) {
    final double cx = rect.center.dx;
    final double r = rect.width / 2;
    final double top = rect.center.dy + r - (centreActive ? 18 : 11);
    final double bottom = rect.center.dy + r + (centreActive ? 10 : 5);

    // The mark gets the same halo treatment when it is the thing being asked
    // for, so "come back to the middle" has something that visibly wants to be
    // aimed at rather than a grey tick that happens to be there.
    if (centreActive) {
      canvas.drawLine(
        Offset(cx, top),
        Offset(cx, bottom),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 9
          ..color = ringColour.withValues(alpha: 0.22),
      );
    }

    final Paint mark = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = centreActive ? 3.5 : 2
      // Dim until it matters. During the sweep the person is meant to be
      // looking AWAY from centre, and a bright marker there would be arguing
      // with the instruction they are following.
      ..color = centreActive
          ? ringColour
          : const Color(0xFFFFFFFF).withValues(alpha: 0.42);

    canvas.drawLine(Offset(cx, top), Offset(cx, bottom), mark);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    if (old.lit.length != lit.length) return true;
    // ⚠ centreActive MUST be compared here. Leave it out and the mark never
    // brightens, because nothing else about the ring changes at the moment the
    // sweep ends — the painter would be asked to repaint and correctly decline.
    if (old.centreActive != centreActive) return true;
    for (int i = 0; i < lit.length; i++) {
      if (old.lit[i] != lit[i]) return true;
    }
    return old.ringColour != ringColour || old.trackColour != trackColour;
  }
}
