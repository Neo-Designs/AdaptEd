import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';

class CelebrationDialog extends StatefulWidget {
  final String badgeName;
  const CelebrationDialog({super.key, required this.badgeName});

  @override
  State<CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<CelebrationDialog> {
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
    _playSuccessSound();
  }

  void _playSuccessSound() async {
    // Make sure to add a "success.mp3" to your assets folder
    await _audioPlayer.play(AssetSource('sounds/success.mp3'));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // The Confetti Rain
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
        ),

        // The Dialog Box
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("🎉 AMAZING JOB! 🎉",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              const SizedBox(height: 20),
              // The visual representation of the badge
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
              ),
              const SizedBox(height: 20),
              Text("You earned the ${widget.badgeName} Badge!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Keep Learning!"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}