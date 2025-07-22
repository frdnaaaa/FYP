import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';

class TranscribePage extends StatefulWidget {
  const TranscribePage({super.key, required this.title});
  final String title;

  @override
  State<TranscribePage> createState() => _TranscribePageState();
}

class _TranscribePageState extends State<TranscribePage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();
  final String _token = 'ff_202310040@_ru';

  String _transcription = '';
  String _audioPath = '';
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isComplete = true;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final Color colorBg = const Color.fromRGBO(147, 96, 242, 1);

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _isComplete = true;
      });
    });
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
    await _recorder.openRecorder();
  }

  Future<void> _startRecording() async {
    final path = 'temp_audio.wav';
    await _recorder.startRecorder(toFile: path);
    await _player.stop();
    setState(() {
      _audioPath = path;
      _isRecording = true;
      _transcription = '';
      _isComplete = true;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stopRecorder();
    setState(() {
      _audioPath = path!;
      _isRecording = false;
    });
    await _player.setSource(DeviceFileSource(_audioPath));
    await _player.stop();
    _transcribeAudio();
  }

  Future<void> _togglePlayback() async {
    if (_audioPath.isEmpty || _isRecording) return;

    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.resume();
      setState(() {
        _isPlaying = true;
        _isComplete = false;
      });
    }
  }

  Future<void> _selectAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg', 'amr'],
    );
    if (result != null) {
      setState(() => _audioPath = result.files.single.path!);
      await _player.setSource(DeviceFileSource(_audioPath));
      _transcribeAudio();
    }
  }

  Future<void> _transcribeAudio() async {
    try {
      setState(() => _isLoading = true);
      final api = ApiService();
      final result = await api.transcribeAudio(File(_audioPath), _token);
      setState(() {
        _transcription = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _transcription = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDuration(Duration d) =>
      '${d.inMinutes.remainder(60)}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(widget.title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(62, 52, 133, 1),
                Color.fromRGBO(65, 54, 139, 1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(65, 54, 139, 1),
              Color.fromRGBO(88, 73, 194, 1),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        child: Column(
          children: [
            const SizedBox(height: 60),
            GestureDetector(
              onTap: _isRecording ? _stopRecording : _startRecording,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 4,
                      offset: const Offset(4, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: colorBg,
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    size: 70,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _selectAudioFile,
              icon: const Icon(Icons.music_note_rounded, size: 16),
              label: const Text(
                'Audio',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorBg,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
              ),
            ),
            const SizedBox(height: 40),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Transcription',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: colorBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: _togglePlayback,
                  ),
                  Text(
                    _isPlaying || !_isComplete
                        ? _formatDuration(_position)
                        : _formatDuration(_duration),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: _duration.inSeconds.toDouble(),
                      value: _position.inSeconds
                          .toDouble()
                          .clamp(0, _duration.inSeconds.toDouble()),
                      onChanged: (val) async {
                        final newPos = Duration(seconds: val.toInt());
                        await _player.seek(newPos);
                        await _player.resume();
                        setState(() {
                          _isPlaying = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 150, maxHeight: 150),
              decoration: BoxDecoration(
                color: colorBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color.fromARGB(126, 255, 255, 255),
                  strokeWidth: 2.0,
                ),
              )
                  : SingleChildScrollView(
                child: Text(
                  _transcription.isNotEmpty
                      ? _transcription
                      : 'No transcription yet.',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
