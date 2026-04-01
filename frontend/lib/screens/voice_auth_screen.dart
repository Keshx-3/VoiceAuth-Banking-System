// lib/screens/voice_auth_screen.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/main_container.dart';
import '../api_service/api_service.dart';
import 'login_screen.dart';

class VoiceAuthScreen extends StatefulWidget {
  const VoiceAuthScreen({super.key});

  @override
  State<VoiceAuthScreen> createState() => _VoiceAuthScreenState();
}

class _VoiceAuthScreenState extends State<VoiceAuthScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Current sample being recorded (0 = first, 1 = second)
  int _currentSample = 0;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isSubmitting = false;
  int? _playingSampleIndex;

  // Store paths and durations for both recordings
  String? _recordingPath1;
  String? _recordingPath2;
  Duration _recordingDuration1 = Duration.zero;
  Duration _recordingDuration2 = Duration.zero;
  Duration _currentRecordingDuration = Duration.zero;

  // Maximum recording duration
  static const Duration _maxRecordingDuration = Duration(seconds: 5);
  late AnimationController _pulseController;

  // Sentences for voice authentication — shuffled randomly each time
  static const List<String> _allSentences = [
    "My voice is my password and I trust it completely.",
    "Technology changes the way we communicate every single day.",
  ];
  late final List<String> _sentences;

  @override
  void initState() {
    super.initState();
    _sentences = List<String>.from(_allSentences)..shuffle(Random());
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingSampleIndex = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  bool get _hasBothRecordings =>
      _recordingPath1 != null && _recordingPath2 != null;

  bool get _hasCurrentRecording =>
      _currentSample == 0 ? _recordingPath1 != null : _recordingPath2 != null;

  String get _currentSentence => _sentences[_currentSample];

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        // Get temporary directory for storing the recording
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_auth_sample${_currentSample + 1}_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _currentRecordingDuration = Duration.zero;
        });

        // Update recording duration
        _updateRecordingDuration();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateRecordingDuration() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() {
          _currentRecordingDuration += const Duration(seconds: 1);
        });
        // Auto-stop after max duration
        if (_currentRecordingDuration >= _maxRecordingDuration) {
          _stopRecording();
        } else {
          _updateRecordingDuration();
        }
      }
    });
  }

  void _showRecordingWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: const Text('Recording Limit'),
        content: const Text(
          'You need to record 2 voice samples (5 seconds each) for voice registration. '
          'Each recording will automatically stop after 5 seconds. '
          'Please read the displayed sentence clearly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();

      if (path != null) {
        setState(() {
          _isRecording = false;
          if (_currentSample == 0) {
            _recordingPath1 = path;
            _recordingDuration1 = _currentRecordingDuration;
          } else {
            _recordingPath2 = path;
            _recordingDuration2 = _currentRecordingDuration;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playRecording(int sampleIndex) async {
    final path = sampleIndex == 0 ? _recordingPath1 : _recordingPath2;
    if (path == null) return;

    try {
      if (_isPlaying && _playingSampleIndex == sampleIndex) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _playingSampleIndex = null;
        });
      } else {
        if (_isPlaying) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() {
          _isPlaying = true;
          _playingSampleIndex = sampleIndex;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play recording: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reRecordSample(int sampleIndex) {
    setState(() {
      _currentSample = sampleIndex;
      if (sampleIndex == 0) {
        _recordingPath1 = null;
        _recordingDuration1 = Duration.zero;
      } else {
        _recordingPath2 = null;
        _recordingDuration2 = Duration.zero;
      }
    });
  }

  void _proceedToNextSample() {
    if (_currentSample == 0 && _recordingPath1 != null) {
      setState(() {
        _currentSample = 1;
      });
    }
  }

  Future<void> _submitVoice() async {
    if (_recordingPath1 == null || _recordingPath2 == null) return;

    setState(() => _isSubmitting = true);

    try {
      await BankingApiService().registerVoice(
        File(_recordingPath1!),
        File(_recordingPath2!),
      );

      if (mounted) {
        // Show success alert
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            title: const Text('Voice Registration Complete'),
            content: const Text(
              'Your voice has been registered successfully. You can now use voice authentication.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate to dashboard
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const MainContainer(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Continue to Dashboard'),
              ),
            ],
          ),
        );
      }
    } on AuthenticationException catch (e) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register voice: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildRecordingCard(int sampleIndex, String? path, Duration duration) {
    final isCurrentSample = _currentSample == sampleIndex;
    final hasRecording = path != null;
    final isPlayingThis = _isPlaying && _playingSampleIndex == sampleIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasRecording ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentSample && !hasRecording
              ? Theme.of(context).colorScheme.primary
              : hasRecording
                  ? Colors.green[300]!
                  : Colors.grey[300]!,
          width: isCurrentSample && !hasRecording ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Sample number indicator
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasRecording
                  ? Colors.green
                  : isCurrentSample
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400],
            ),
            child: Center(
              child: hasRecording
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '${sampleIndex + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sample ${sampleIndex + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasRecording
                      ? 'Duration: ${_formatDuration(duration)}'
                      : isCurrentSample
                          ? 'Ready to record'
                          : 'Not recorded',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (hasRecording) ...[
            // Play button
            IconButton(
              onPressed: _isSubmitting ? null : () => _playRecording(sampleIndex),
              icon: Icon(
                isPlayingThis ? Icons.pause : Icons.play_arrow,
                color: Theme.of(context).colorScheme.primary,
              ),
              tooltip: isPlayingThis ? 'Pause' : 'Play',
            ),
            // Re-record button
            IconButton(
              onPressed: _isSubmitting ? null : () => _reRecordSample(sampleIndex),
              icon: Icon(
                Icons.refresh,
                color: Colors.orange[700],
              ),
              tooltip: 'Re-record',
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Authentication'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header icon and title
              Icon(
                Icons.record_voice_over,
                size: 50,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Voice Registration',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Record 2 voice samples by reading the sentences',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _showRecordingWarning,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressDot(0),
                  Container(
                    width: 40,
                    height: 2,
                    color: _recordingPath1 != null
                        ? Colors.green
                        : Colors.grey[300],
                  ),
                  _buildProgressDot(1),
                ],
              ),

              const SizedBox(height: 24),

              // Sentence card with record button on top
              if (!_hasBothRecordings || _currentSample < 2)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Sentence display card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Sentence ${_currentSample + 1} of 2',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Icon(
                            Icons.format_quote,
                            color: Color(0xFF1A73E8),
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentSentence,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              color: Color(0xFF1A237E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Record button positioned on top
                    Positioned(
                      top: -30,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _isSubmitting || _hasCurrentRecording
                              ? null
                              : (_isRecording ? _stopRecording : _startRecording),
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _hasCurrentRecording
                                      ? Colors.green
                                      : _isRecording
                                          ? Colors.red
                                          : Theme.of(context).colorScheme.primary,
                                  boxShadow: _isRecording
                                      ? [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(
                                                0.3 +
                                                    _pulseController.value * 0.3),
                                            blurRadius:
                                                10 + _pulseController.value * 10,
                                            spreadRadius:
                                                _pulseController.value * 5,
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: (_hasCurrentRecording
                                                    ? Colors.green
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .primary)
                                                .withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Icon(
                                  _hasCurrentRecording
                                      ? Icons.check
                                      : _isRecording
                                          ? Icons.stop
                                          : Icons.mic,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // Recording status
              const SizedBox(height: 16),
              if (_isRecording)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recording... ${_formatDuration(_currentRecordingDuration)} / ${_formatDuration(_maxRecordingDuration)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

              // Next sample button (after first recording)
              if (_currentSample == 0 && _recordingPath1 != null && !_isRecording)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FilledButton.icon(
                    onPressed: _proceedToNextSample,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Record Next Sample'),
                  ),
                ),

              const SizedBox(height: 20),

              // Recordings list
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Voice Samples',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildRecordingCard(0, _recordingPath1, _recordingDuration1),
              _buildRecordingCard(1, _recordingPath2, _recordingDuration2),

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed:
                      (_hasBothRecordings && !_isSubmitting) ? _submitVoice : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Submit Voice Registration'),
                ),
              ),

              const SizedBox(height: 12),

              // Skip for now text (optional)
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const MainContainer(),
                          ),
                          (route) => false,
                        );
                      },
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDot(int index) {
    final isCompleted =
        index == 0 ? _recordingPath1 != null : _recordingPath2 != null;
    final isCurrent = _currentSample == index;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? Colors.green
            : isCurrent
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}
