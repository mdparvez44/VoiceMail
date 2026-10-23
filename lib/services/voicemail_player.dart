import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

class VoicemailPlayer {
  VoicemailPlayer();

  final AudioPlayer _player = AudioPlayer();

  Future<void> play(String path) async {
    if (!await File(path).exists()) {
      throw Exception('The audio recording could not be found.');
    }

    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
