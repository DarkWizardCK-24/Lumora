import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Looping background sounds bundled in assets/sounds (synthesised by tool/gen_sounds.dart).
enum AmbientSound {
  off('off', 'Off', Icons.volume_off_rounded),
  rain('rain', 'Rain', Icons.grain_rounded),
  waves('waves', 'Waves', Icons.waves_rounded),
  wind('wind', 'Wind', Icons.air_rounded),
  brown('brown', 'Deep hum', Icons.graphic_eq_rounded),
  white('white', 'White noise', Icons.blur_on_rounded);

  const AmbientSound(this.id, this.label, this.icon);
  final String id, label;
  final IconData icon;

  String? get asset => this == off ? null : 'sounds/$id.wav';

  static AmbientSound byId(String id) =>
      AmbientSound.values.firstWhere((s) => s.id == id, orElse: () => AmbientSound.off);
}

/// Thin wrapper so audio problems can never crash the focus screen.
class AmbientPlayer {
  final _log = Logger('ambient');
  AudioPlayer? _player;
  AmbientSound _current = AmbientSound.off;

  AmbientSound get current => _current;

  Future<void> play(AmbientSound sound, double volume) async {
    try {
      if (sound == AmbientSound.off) {
        await stop();
        return;
      }
      final p = _player ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(volume.clamp(0.0, 1.0));
      if (_current != sound) await p.play(AssetSource(sound.asset!));
      _current = sound;
    } catch (e, st) {
      _log.warning('Could not play ${sound.id}', e, st);
    }
  }

  Future<void> setVolume(double v) async {
    try {
      await _player?.setVolume(v.clamp(0.0, 1.0));
    } catch (e) {
      _log.warning('Could not change volume', e);
    }
  }

  Future<void> stop() async {
    _current = AmbientSound.off;
    try {
      await _player?.stop();
    } catch (e) {
      _log.warning('Could not stop audio', e);
    }
  }

  Future<void> dispose() async {
    _current = AmbientSound.off;
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
