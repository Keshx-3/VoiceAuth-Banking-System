// lib/widgets/voice_verification_dialog.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../api_service/api_service.dart';
import 'upi_pin_screen.dart';

/// Shows a voice verification dialog and returns true if verification succeeds
Future<bool> showVoiceVerificationDialog(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => const VoiceVerificationSheet(),
  );
  return result ?? false;
}

/// Shows a full-screen UPI PIN verification screen (used when voice-auth is OFF)
/// Returns true if PIN verification succeeds
Future<bool> showPinVerificationDialog(BuildContext context, {double? amount, String? accountInfo}) async {
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (context) => UpiPinScreen(
        amount: amount,
        accountInfo: accountInfo,
      ),
    ),
  );
  return result ?? false;
}

class VoiceVerificationSheet extends StatefulWidget {
  const VoiceVerificationSheet({super.key});

  @override
  State<VoiceVerificationSheet> createState() => _VoiceVerificationSheetState();
}

class _VoiceVerificationSheetState extends State<VoiceVerificationSheet>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isVerifying = false;
  bool _hasRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  String? _errorMessage;
  double? _failedSimilarity;  // Similarity score when verification fails

  late AnimationController _pulseController;

  // Maximum recording duration
  static const Duration _maxRecordingDuration = Duration(seconds: 5);

  // Verification sentences — one is picked at random each time
  static const List<String> _verificationSentences = [
    "My voice is my password and I trust it completely.",
    "Technology changes the way we communicate every single day.",
  ];
  late final String _verificationSentence;

  @override
  void initState() {
    super.initState();
    _verificationSentence = _verificationSentences[Random().nextInt(_verificationSentences.length)];
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_verify_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _hasRecording = false;
          _recordingPath = null;
          _recordingDuration = Duration.zero;
          _errorMessage = null;
        });

        _updateRecordingDuration();
      } else {
        setState(() {
          _errorMessage = 'Microphone permission is required';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start recording';
      });
    }
  }

  void _updateRecordingDuration() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
        if (_recordingDuration >= _maxRecordingDuration) {
          _stopRecording();
        } else {
          _updateRecordingDuration();
        }
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _hasRecording = true;
          _recordingPath = path;
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMessage = 'Failed to stop recording';
      });
    }
  }

  Future<void> _verifyVoice() async {
    if (_recordingPath == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _failedSimilarity = null;
    });

    try {
      final result = await BankingApiService().verifyVoice(File(_recordingPath!));
      
      if (result.authenticated) {
        // Voice is authenticated, proceed with payment
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        // Voice not authenticated, show similarity score and PIN option
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _failedSimilarity = result.similarityPercent;
            _errorMessage = 'Voice not recognized';
            _hasRecording = false;
            _recordingPath = null;
            _recordingDuration = Duration.zero;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _failedSimilarity = null;
          _hasRecording = false;
          _recordingPath = null;
          _recordingDuration = Duration.zero;
        });
      }
    }
  }

  void _cancel() {
    Navigator.of(context).pop(false);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Security icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.security,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Voice Verification',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please read the sentence below to verify your identity',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Sentence card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.format_quote,
                  color: Color(0xFF1A73E8),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  _verificationSentence,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A237E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Maximum 5 seconds',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Record button
          GestureDetector(
            onTap: _isVerifying || _hasRecording
                ? null
                : (_isRecording ? _stopRecording : _startRecording),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasRecording
                        ? Colors.green
                        : _isRecording
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                    boxShadow: _isRecording
                        ? [
                            BoxShadow(
                              color: Colors.red
                                  .withOpacity(0.3 + _pulseController.value * 0.3),
                              blurRadius: 10 + _pulseController.value * 10,
                              spreadRadius: _pulseController.value * 5,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: (_hasRecording
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.primary)
                                  .withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Icon(
                    _hasRecording
                        ? Icons.check
                        : _isRecording
                            ? Icons.stop
                            : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Recording status
          if (_isRecording)
            Text(
              'Recording... ${_formatDuration(_recordingDuration)} / ${_formatDuration(_maxRecordingDuration)}',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            )
          else if (_hasRecording)
            const Text(
              'Recording complete',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              'Tap to record',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),

          // Error message with similarity score
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // Show similarity score if available
                  if (_failedSimilarity != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Voice Similarity',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${_failedSimilarity!.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: _failedSimilarity! < 50
                                      ? Colors.red[700]
                                      : Colors.orange[700],
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _failedSimilarity! < 50
                                    ? Icons.trending_down
                                    : Icons.trending_flat,
                                color: _failedSimilarity! < 50
                                    ? Colors.red[700]
                                    : Colors.orange[700],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _failedSimilarity! < 50
                                ? 'Voice is very different from registered voice'
                                : 'Voice is somewhat different from registered voice',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please try again in a quiet environment',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ],

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isVerifying || _isRecording ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: (_hasRecording && !_isVerifying) ? _verifyVoice : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Verify'),
                ),
              ),
            ],
          ),

          // Extra padding for bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
