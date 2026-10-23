import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoicemailRecorder {
  VoicemailRecorder();

  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  Future<String> startRecording() async {
    final hasMicPermission = await _recorder.hasPermission();

    if (!hasMicPermission) {
      throw Exception('Microphone permission was not granted.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final recordingsDirectory = Directory('${directory.path}/voicemails');

    if (!await recordingsDirectory.exists()) {
      await recordingsDirectory.create(recursive: true);
    }

    final filename = 'voicemail_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = '${recordingsDirectory.path}/$filename';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    return path;
  }

  Future<String?> stopRecording() async {
    return _recorder.stop();
  }

  Future<bool> get isRecording async {
    return _recorder.isRecording();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
