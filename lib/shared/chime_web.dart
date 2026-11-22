import 'package:web/web.dart' as web;

// Single AudioContext for the app's lifetime. Creating one per chime leaks
// and some browsers cap the total count per origin.
web.AudioContext? _ctx;
web.AudioContext _context() => _ctx ??= web.AudioContext();

/// Plays a short two-note "ding-ding" using the Web Audio API.
///
/// Browser autoplay policy: `AudioContext` starts in the `suspended` state
/// until a user gesture (click/tap) happens on the page. We nudge
/// `resume()` on every chime; the first call after a cold page load may
/// still be silent, subsequent ones work normally.
void playChime() {
  final ctx = _context();
  if (ctx.state == 'suspended') {
    ctx.resume();
  }
  _note(ctx, freq: 880, offset: 0.0, duration: 0.18); // A5
  _note(ctx, freq: 1319, offset: 0.14, duration: 0.28); // E6
}

/// Schedules a single bell-shaped note.
///
/// `offset` is seconds from "now" and `duration` is how long the note runs.
/// The gain envelope ramps quickly up (2ms attack) then decays
/// exponentially — this gives a bell-ish timbre on a pure sine wave.
void _note(
  web.AudioContext ctx, {
  required double freq,
  required double offset,
  required double duration,
}) {
  final osc = ctx.createOscillator();
  final gain = ctx.createGain();
  osc.frequency.value = freq;
  osc.type = 'sine';
  osc.connect(gain);
  gain.connect(ctx.destination);

  final start = ctx.currentTime + offset;
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(0.25, start + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);

  osc.start(start);
  osc.stop(start + duration);
}
