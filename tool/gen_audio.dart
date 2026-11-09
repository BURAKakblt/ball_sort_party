// ignore_for_file: avoid_print
// Synthesizes every sound in assets/audio from scratch (no samples, no
// third-party material). Output is 16-bit PCM WAV.
//
// Usage: dart run tool/gen_audio.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sfxRate = 44100;
const _musicRate = 22050;

void main() {
  final sfx = <String, Float64List Function()>{
    'land_basketball': _landBasketball,
    'land_football': _landFootball,
    'land_baseball': _landBaseball,
    'land_tennis': _landTennis,
    'land_volleyball': _landVolleyball,
    'select': _select,
    'invalid': _invalid,
    'button': _button,
    'bottle_complete': _bottleComplete,
    'win': _win,
    'lose': _lose,
    'gift_open': _giftOpen,
    'coin': _coin,
    'life': _life,
    'purchase': _purchase,
  };
  Directory('assets/audio/sfx').createSync(recursive: true);
  Directory('assets/audio/music').createSync(recursive: true);
  for (final e in sfx.entries) {
    final data = _finish(e.value(), _sfxRate, peakDb: e.key == 'invalid' ? -9 : -3);
    _writeWav('assets/audio/sfx/${e.key}.wav', data, _sfxRate);
  }
  final music = _music();
  _writeWav('assets/audio/music/party_loop.wav', _finish(music, _musicRate, peakDb: -4, fade: false), _musicRate);

  // Single-impact variants for the "reduce motion" setting (no rebounds in
  // the animation → no rebounds in the sound). Generated last so the noise
  // sequence of the files above stays identical.
  final single = <String, Float64List Function()>{
    'land_basketball_single': () => _landBasketball(single: true),
    'land_football_single': () => _landFootball(single: true),
    'land_baseball_single': () => _landBaseball(single: true),
    'land_tennis_single': () => _landTennis(single: true),
    'land_volleyball_single': () => _landVolleyball(single: true),
  };
  for (final e in single.entries) {
    _writeWav('assets/audio/sfx/${e.key}.wav', _finish(e.value(), _sfxRate), _sfxRate);
  }
  print('Generated ${sfx.length + single.length} effects + 1 music loop.');
}

// ------------------------------------------------------------------ helpers

final _rnd = math.Random(20261109);

Float64List _buf(double seconds, [int rate = _sfxRate]) => Float64List((seconds * rate).ceil());

/// Adds an oscillator. [freq] and [amp] are functions of time since start.
void _osc(
  Float64List b,
  double start,
  double dur,
  double Function(double t) freq,
  double Function(double t) amp, {
  String wave = 'sine',
  int rate = _sfxRate,
  bool wrap = false,
}) {
  var phase = 0.0;
  final s0 = (start * rate).round();
  final n = (dur * rate).round();
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    phase += freq(t) / rate;
    final p = phase - phase.floorToDouble();
    final v = switch (wave) {
      'tri' => 4 * (p < 0.5 ? p : 1 - p) - 1,
      'square' => p < 0.5 ? 1.0 : -1.0,
      _ => math.sin(2 * math.pi * p),
    };
    var idx = s0 + i;
    if (wrap) {
      idx %= b.length;
    } else if (idx >= b.length) {
      break;
    }
    b[idx] += v * amp(t);
  }
}

/// Adds filtered noise. [lowpass]/[highpass] are cutoff frequencies in Hz.
void _noise(
  Float64List b,
  double start,
  double dur,
  double Function(double t) amp, {
  double? lowpass,
  double? highpass,
  int rate = _sfxRate,
  bool wrap = false,
}) {
  final s0 = (start * rate).round();
  final n = (dur * rate).round();
  final aL = lowpass == null ? 1.0 : 1 - math.exp(-2 * math.pi * lowpass / rate);
  final aH = highpass == null ? 0.0 : math.exp(-2 * math.pi * highpass / rate);
  var lp = 0.0, hpIn = 0.0, hpOut = 0.0;
  for (var i = 0; i < n; i++) {
    final x = _rnd.nextDouble() * 2 - 1;
    lp += aL * (x - lp);
    var y = lp;
    if (highpass != null) {
      hpOut = aH * (hpOut + y - hpIn);
      hpIn = y;
      y = hpOut;
    }
    var idx = s0 + i;
    if (wrap) {
      idx %= b.length;
    } else if (idx >= b.length) {
      break;
    }
    b[idx] += y * amp(i / rate);
  }
}

double Function(double) _decay(double rate, {double attack = 0.002, double gain = 1}) =>
    (t) => gain * (t < attack ? t / attack : math.exp(-(t - attack) * rate));

double _note(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

/// Bell / marimba-like tone with inharmonic partials.
void _bell(Float64List b, double start, double f, double gain, {double decay = 6, int rate = _sfxRate, bool wrap = false}) {
  _osc(b, start, 6 / decay + 0.1, (_) => f, _decay(decay, gain: gain), rate: rate, wrap: wrap);
  _osc(b, start, 3 / decay, (_) => f * 2.76, _decay(decay * 2.2, gain: gain * 0.35), rate: rate, wrap: wrap);
  _osc(b, start, 2 / decay, (_) => f * 5.4, _decay(decay * 4, gain: gain * 0.12), rate: rate, wrap: wrap);
}

/// One ball impact: pitched body + transient noise.
void _impact(
  Float64List b,
  double at,
  double gain, {
  required double f0,
  required double f1,
  required double bodyDecay,
  required double noiseGain,
  double? noiseLp,
  double? noiseHp,
  double noiseDecay = 120,
}) {
  _osc(b, at, 6 / bodyDecay, (t) => f1 + (f0 - f1) * math.exp(-t * 30), _decay(bodyDecay, gain: gain));
  _noise(b, at, 0.05, _decay(noiseDecay, gain: gain * noiseGain), lowpass: noiseLp, highpass: noiseHp);
}

/// Soft-limit, fade edges, normalize to [peakDb].
Float64List _finish(Float64List b, int rate, {double peakDb = -3, bool fade = true}) {
  for (var i = 0; i < b.length; i++) {
    b[i] = _tanh(b[i] * 1.2);
  }
  if (fade) {
    final f = (0.004 * rate).round();
    for (var i = 0; i < f && i < b.length; i++) {
      b[b.length - 1 - i] *= i / f;
    }
  }
  var peak = 0.0;
  for (final v in b) {
    peak = math.max(peak, v.abs());
  }
  final target = math.pow(10, peakDb / 20);
  if (peak > 0) {
    for (var i = 0; i < b.length; i++) {
      b[i] *= target / peak;
    }
  }
  return b;
}

double _tanh(double x) {
  final e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

void _writeWav(String path, Float64List data, int rate) {
  final bytes = BytesBuilder();
  final dataLen = data.length * 2;
  void str(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => bytes.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  str('RIFF');
  u32(36 + dataLen);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  str('data');
  u32(dataLen);
  final pcm = ByteData(dataLen);
  for (var i = 0; i < data.length; i++) {
    pcm.setInt16(i * 2, (data[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  bytes.add(pcm.buffer.asUint8List());
  File(path).writeAsBytesSync(bytes.toBytes());
  print('  $path  ${(data.length / rate).toStringAsFixed(2)}s');
}

// ------------------------------------------------------------------ ball landings
// Rebound timings roughly follow the animation profiles in ball_component.dart.

Float64List _landBasketball({bool single = false}) {
  final b = _buf(single ? 0.22 : 0.55);
  for (final (at, g) in single ? [(0.0, 1.0)] : [(0.0, 1.0), (0.24, 0.42), (0.38, 0.16)]) {
    _impact(b, at, g, f0: 150, f1: 72, bodyDecay: 13, noiseGain: 0.45, noiseLp: 1400);
    // Rubbery shell ring.
    _osc(b, at, 0.2, (_) => 215, _decay(24, gain: g * 0.22));
  }
  return b;
}

Float64List _landFootball({bool single = false}) {
  final b = _buf(single ? 0.16 : 0.35);
  for (final (at, g) in single ? [(0.0, 1.0)] : [(0.0, 1.0), (0.2, 0.3)]) {
    _impact(b, at, g, f0: 210, f1: 115, bodyDecay: 26, noiseGain: 0.5, noiseLp: 3200, noiseHp: 600, noiseDecay: 90);
  }
  return b;
}

Float64List _landBaseball({bool single = false}) {
  final b = _buf(single ? 0.075 : 0.18);
  // Hard, short wooden "tock".
  _osc(b, 0, 0.12, (_) => 560, _decay(48, gain: 0.8));
  _osc(b, 0, 0.06, (_) => 1340, _decay(80, gain: 0.3));
  _noise(b, 0, 0.03, _decay(260, gain: 0.9), highpass: 2200);
  if (!single) _impact(b, 0.08, 0.18, f0: 600, f1: 520, bodyDecay: 60, noiseGain: 0.4, noiseHp: 2500);
  return b;
}

Float64List _landTennis({bool single = false}) {
  final b = _buf(single ? 0.12 : 0.42);
  for (final (at, g) in single ? [(0.0, 1.0)] : [(0.0, 1.0), (0.15, 0.45), (0.245, 0.2), (0.31, 0.08)]) {
    _impact(b, at, g, f0: 470, f1: 310, bodyDecay: 38, noiseGain: 0.55, noiseHp: 2800, noiseDecay: 200);
  }
  return b;
}

Float64List _landVolleyball({bool single = false}) {
  final b = _buf(single ? 0.2 : 0.45);
  for (final (at, g) in single ? [(0.0, 0.8)] : [(0.0, 0.8), (0.22, 0.22)]) {
    _impact(b, at, g, f0: 160, f1: 98, bodyDecay: 12, noiseGain: 0.6, noiseLp: 900, noiseDecay: 28);
  }
  return b;
}

// ------------------------------------------------------------------ UI sounds

Float64List _select() {
  final b = _buf(0.12);
  _osc(b, 0, 0.11, (t) => 560 + 900 * math.min(1, t / 0.06), _decay(30, attack: 0.004, gain: 0.8));
  _osc(b, 0, 0.08, (t) => 2 * (560 + 900 * math.min(1, t / 0.06)), _decay(45, gain: 0.15));
  return b;
}

Float64List _invalid() {
  final b = _buf(0.3);
  _osc(b, 0, 0.12, (_) => 233, _decay(22, attack: 0.006, gain: 0.7), wave: 'tri');
  _osc(b, 0.11, 0.18, (_) => 185, _decay(16, attack: 0.006, gain: 0.7), wave: 'tri');
  return b;
}

Float64List _button() {
  final b = _buf(0.07);
  _osc(b, 0, 0.06, (t) => 1100 - 4000 * t, _decay(70, gain: 0.8));
  _noise(b, 0, 0.01, _decay(400, gain: 0.2), highpass: 3000);
  return b;
}

Float64List _bottleComplete() {
  final b = _buf(1.1);
  const notes = [76, 80, 83, 88]; // E6 G#6 B6 E7
  for (var i = 0; i < notes.length; i++) {
    _bell(b, i * 0.07, _note(notes[i]), 0.5, decay: 5);
  }
  // Shimmer.
  for (var i = 0; i < 10; i++) {
    _bell(b, 0.3 + i * 0.045, _note(88 + (i % 3) * 4), 0.08, decay: 9);
  }
  return b;
}

Float64List _win() {
  final b = _buf(2.2);
  const run = [60, 64, 67, 72, 76]; // C major run
  for (var i = 0; i < run.length; i++) {
    final f = _note(run[i] + 12);
    _osc(b, i * 0.1, 0.3, (_) => f, _decay(9, gain: 0.35), wave: 'tri');
    _bell(b, i * 0.1, f, 0.25, decay: 7);
  }
  // Final chord.
  for (final m in [72, 76, 79, 84]) {
    final f = _note(m);
    _osc(b, 0.52, 1.6, (_) => f, (t) => 0.22 * math.min(1, t / 0.02) * math.exp(-t * 2.2), wave: 'tri');
    _osc(b, 0.52, 1.6, (_) => f * 1.003, (t) => 0.12 * math.exp(-t * 2.5));
  }
  for (var i = 0; i < 8; i++) {
    _bell(b, 0.55 + i * 0.07, _note(91 + (i % 4) * 2), 0.07, decay: 8);
  }
  return b;
}

Float64List _lose() {
  final b = _buf(1.5);
  const notes = [67, 66, 65]; // G4 F#4 F4
  for (var i = 0; i < notes.length; i++) {
    final f = _note(notes[i]);
    _osc(b, i * 0.26, 0.3, (_) => f, _decay(7, attack: 0.02, gain: 0.45), wave: 'tri');
  }
  // Last, longer note with a gentle wobble.
  final f = _note(64);
  _osc(b, 0.78, 0.7, (t) => f * (1 + 0.012 * math.sin(t * 2 * math.pi * 5.5)), (t) => 0.45 * math.min(1, t / 0.03) * math.exp(-t * 3), wave: 'tri');
  return b;
}

Float64List _giftOpen() {
  final b = _buf(1.4);
  // Whoosh: noise with rising cutoff, built from short slices.
  for (var i = 0; i < 14; i++) {
    final t0 = i * 0.025;
    _noise(b, t0, 0.04, (t) => 0.22 * math.sin(math.pi * (i + t / 0.04) / 15), lowpass: 500 + i * 300.0);
  }
  // Pop.
  _impact(b, 0.33, 0.6, f0: 420, f1: 260, bodyDecay: 30, noiseGain: 0.5, noiseHp: 1500);
  // Sparkle arpeggio.
  const notes = [79, 83, 86, 91, 95];
  for (var i = 0; i < notes.length; i++) {
    _bell(b, 0.38 + i * 0.06, _note(notes[i]), 0.3, decay: 6);
  }
  return b;
}

Float64List _coin() {
  final b = _buf(0.5);
  _osc(b, 0, 0.08, (_) => _note(83), (t) => 0.4, wave: 'square');
  _osc(b, 0.075, 0.4, (_) => _note(88), _decay(9, gain: 0.4), wave: 'square');
  _bell(b, 0.075, _note(88), 0.3, decay: 8);
  // Soften the square wave with a crude lowpass.
  var y = 0.0;
  for (var i = 0; i < b.length; i++) {
    y += 0.35 * (b[i] - y);
    b[i] = y;
  }
  return b;
}

Float64List _life() {
  final b = _buf(1.1);
  const notes = [69, 73, 76, 81];
  for (var i = 0; i < notes.length; i++) {
    final f = _note(notes[i]);
    _osc(b, i * 0.08, 0.7, (_) => f, _decay(5, attack: 0.01, gain: 0.3));
    _osc(b, i * 0.08, 0.5, (_) => f * 2, _decay(8, gain: 0.1), wave: 'tri');
  }
  _bell(b, 0.35, _note(93), 0.15, decay: 6);
  return b;
}

Float64List _purchase() {
  final b = _buf(0.9);
  _noise(b, 0, 0.05, _decay(90, gain: 0.35), highpass: 3500);
  _noise(b, 0.08, 0.05, _decay(90, gain: 0.3), highpass: 4500);
  _bell(b, 0.12, _note(84), 0.45, decay: 5);
  _bell(b, 0.12, _note(91), 0.25, decay: 6);
  return b;
}

// ------------------------------------------------------------------ music

/// 16-bar cheerful loop at 100 BPM. All voices wrap around the buffer end, so
/// note tails continue seamlessly into the start of the next loop.
Float64List _music() {
  const bpm = 100.0;
  const beat = 60 / bpm;
  const bar = beat * 4;
  const rate = _musicRate;
  final b = _buf(bar * 16, rate);

  // Chords as MIDI roots + quality.
  const chords = [
    [48, 52, 55], [45, 48, 52], [41, 45, 48], [43, 47, 50], // C Am F G
    [48, 52, 55], [40, 43, 47], [41, 45, 48], [43, 47, 50], // C Em F G
    [45, 48, 52], [41, 45, 48], [48, 52, 55], [43, 47, 50], // Am F C G
    [41, 45, 48], [43, 47, 50], [48, 52, 55], [43, 47, 53], // F G C G7
  ];

  // Simple melody (MIDI, 0 = rest), one entry per half beat, 8 per bar.
  const melody = [
    72, 0, 76, 0, 79, 0, 76, 0, /**/ 72, 0, 0, 0, 69, 0, 72, 0,
    77, 0, 76, 0, 74, 0, 72, 0, /**/ 71, 0, 74, 0, 79, 0, 0, 0,
    72, 0, 76, 0, 79, 0, 81, 0, /**/ 79, 0, 76, 0, 71, 0, 0, 0,
    74, 0, 72, 0, 69, 0, 72, 0, /**/ 74, 0, 0, 0, 0, 0, 0, 0,
    76, 0, 0, 72, 69, 0, 72, 0, /**/ 77, 0, 76, 0, 72, 0, 0, 0,
    79, 0, 76, 0, 72, 0, 76, 0, /**/ 74, 0, 71, 0, 67, 0, 0, 0,
    77, 0, 81, 0, 77, 0, 72, 0, /**/ 74, 0, 79, 0, 77, 0, 74, 0,
    72, 0, 0, 0, 76, 0, 0, 0, /**/ 72, 0, 0, 0, 0, 0, 0, 0,
  ];

  for (var bi = 0; bi < 16; bi++) {
    final t0 = bi * bar;
    final c = chords[bi];

    // Pad: detuned sines with slow attack, one octave up.
    for (final m in c) {
      final f = _note(m + 12);
      for (final detune in [0.997, 1.003]) {
        _osc(b, t0, bar + 0.6, (_) => f * detune,
            (t) => 0.045 * math.min(1, t / 0.4) * (t > bar ? math.exp(-(t - bar) * 6) : 1),
            rate: rate, wrap: true);
      }
    }

    // Bass: root on 1, the "and" of 2, and 3.
    final root = _note(c.first - 12);
    for (final pos in [0.0, 1.5, 2.0]) {
      _osc(b, t0 + pos * beat, 0.5, (_) => root, _decay(5, attack: 0.01, gain: 0.22), rate: rate, wrap: true);
      _osc(b, t0 + pos * beat, 0.3, (_) => root * 2, _decay(9, gain: 0.05), wave: 'tri', rate: rate, wrap: true);
    }

    // Marimba arpeggio on 8th notes.
    final arp = [c[0], c[1], c[2], c[0] + 12, c[2], c[1], c[0] + 12, c[2]];
    for (var k = 0; k < 8; k++) {
      _bell(b, t0 + k * beat / 2, _note(arp[k] + 12), 0.05, decay: 9, rate: rate, wrap: true);
    }

    // Melody (soft bell-ish lead).
    for (var k = 0; k < 8; k++) {
      final m = melody[bi * 8 + k];
      if (m == 0) continue;
      final f = _note(m);
      _osc(b, t0 + k * beat / 2, 0.6, (_) => f, _decay(4.5, attack: 0.008, gain: 0.09), wave: 'tri', rate: rate, wrap: true);
      _bell(b, t0 + k * beat / 2, f, 0.05, decay: 5, rate: rate, wrap: true);
    }

    // Drums: soft kick on 1 & 3, light clap on 2 & 4, shaker on off-beats.
    for (final k in [0, 2]) {
      _osc(b, t0 + k * beat, 0.2, (t) => 45 + 70 * math.exp(-t * 35), _decay(18, gain: 0.3), rate: rate, wrap: true);
    }
    for (final k in [1, 3]) {
      _noise(b, t0 + k * beat, 0.12, _decay(30, gain: 0.07), lowpass: 4000, highpass: 900, rate: rate, wrap: true);
    }
    for (var k = 0; k < 8; k++) {
      _noise(b, t0 + (k + 0.5) * beat / 2, 0.05, _decay(70, gain: k.isOdd ? 0.04 : 0.025),
          highpass: 5000, rate: rate, wrap: true);
    }
  }
  return b;
}
