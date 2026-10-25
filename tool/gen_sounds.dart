// Generates the bundled ambient focus loops (assets/sounds/*.wav).
// Run from the project root:  dart run tool/gen_sounds.dart
// Everything is synthesised, so there is nothing to download or license.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const rate = 22050;
const seconds = 12;
const fade = rate; // 1 s crossfade so the loop point is inaudible

void main() {
  Directory('assets/sounds').createSync(recursive: true);
  _write('rain', _rain());
  _write('white', _white());
  _write('brown', _brown());
  _write('waves', _waves());
  _write('wind', _wind());
}

List<double> _gen(double Function(int i, math.Random r) f, {int seed = 1}) {
  final r = math.Random(seed);
  final n = rate * seconds;
  final x = List<double>.generate(n + fade, (i) => f(i, r));
  return _loop(x, n);
}

List<double> _loop(List<double> x, int n) {
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    if (i < fade) {
      final t = i / fade;
      out[i] = x[i] * t + x[n + i] * (1 - t);
    } else {
      out[i] = x[i];
    }
  }
  return out;
}

List<double> _white() => _gen((i, r) => (r.nextDouble() * 2 - 1) * 0.3);

List<double> _brown() {
  var last = 0.0;
  return _gen((i, r) {
    last = (last + (r.nextDouble() * 2 - 1) * 0.02) / 1.02;
    return last * 7;
  }, seed: 2);
}

List<double> _rain() {
  var lp = 0.0, drop = 0.0;
  return _gen((i, r) {
    final w = r.nextDouble() * 2 - 1;
    lp += (w - lp) * 0.55; // soft hiss
    if (r.nextDouble() < 0.0016) drop = 0.6 + r.nextDouble() * 0.4; // sparse droplets
    drop *= 0.9;
    return lp * 0.32 + (r.nextDouble() * 2 - 1) * drop * 0.35;
  }, seed: 3);
}

List<double> _waves() {
  var lp = 0.0;
  return _gen((i, r) {
    lp += ((r.nextDouble() * 2 - 1) - lp) * 0.06;
    // Two swells per 12 s so the modulation also loops cleanly.
    final swell = 0.55 + 0.45 * math.sin(2 * math.pi * 2 * i / (rate * seconds));
    return lp * 2.4 * swell;
  }, seed: 4);
}

List<double> _wind() {
  var a = 0.0, b = 0.0;
  return _gen((i, r) {
    final w = r.nextDouble() * 2 - 1;
    a += (w - a) * 0.03;
    b += (a - b) * 0.05;
    final gust = 0.6 + 0.4 * math.sin(2 * math.pi * 3 * i / (rate * seconds));
    return b * 5.5 * gust;
  }, seed: 5);
}

void _write(String name, List<double> samples) {
  var peak = 0.0;
  for (final s in samples) {
    peak = math.max(peak, s.abs());
  }
  final gain = peak == 0 ? 1.0 : 0.8 / peak;
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i] * gain * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  File('assets/sounds/$name.wav').writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('wrote assets/sounds/$name.wav');
}
