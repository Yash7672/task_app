import 'package:flutter/material.dart';

class BiometricButton extends StatelessWidget {
  final VoidCallback onPressed;

  const BiometricButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          icon: const Icon(Icons.fingerprint),
          iconSize: 40,
          tooltip: 'Unlock with biometrics',
        ),
        const SizedBox(height: 4),
        Text(
          'Use fingerprint',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
