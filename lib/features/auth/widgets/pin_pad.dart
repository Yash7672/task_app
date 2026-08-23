import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinPad extends StatefulWidget {
  final String title;
  final String? errorText;
  final ValueChanged<String> onPinCompleted;
  final VoidCallback? onBiometricRequested;
  final bool showBiometric;
  final IconData biometricIcon;

  /// When false (e.g. brute-force lockout) the pad ignores all input.
  final bool enabled;

  /// Fires on every digit press so owners can clear stale error text.
  final VoidCallback? onInputChanged;

  const PinPad({
    super.key,
    required this.title,
    this.errorText,
    required this.onPinCompleted,
    this.onBiometricRequested,
    this.showBiometric = false,
    this.biometricIcon = Icons.fingerprint,
    this.enabled = true,
    this.onInputChanged,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _buffer = '';

  void _onDigit(String digit) {
    if (!widget.enabled || _buffer.length >= 4) return;
    HapticFeedback.lightImpact();
    widget.onInputChanged?.call();
    setState(() => _buffer += digit);
    if (_buffer.length == 4) {
      final pin = _buffer;
      Future.delayed(const Duration(milliseconds: 120), () {
        widget.onPinCompleted(pin);
        if (mounted) setState(() => _buffer = '');
      });
    }
  }

  void _onBackspace() {
    if (!widget.enabled || _buffer.isEmpty) return;
    HapticFeedback.selectionClick();
    widget.onInputChanged?.call();
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (widget.errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.errorText!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _buffer.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: filled ? 18 : 14,
                    height: filled ? 18 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          filled ? theme.colorScheme.primary : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 264,
                child: Column(
                  children: [
                    for (final row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                    ])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row
                            .map((d) => _PadButton(
                                label: d, onTap: () => _onDigit(d)))
                            .toList(),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (widget.showBiometric)
                          _PadButton(
                            icon: widget.biometricIcon,
                            onTap: widget.onBiometricRequested ?? () {},
                          )
                        else
                          // Same size + padding as _PadButton (78 + 2×5) so
                          // the '0' stays centered when biometrics are off.
                          const Padding(
                            padding: EdgeInsets.all(5),
                            child: SizedBox(width: 78, height: 60),
                          ),
                        _PadButton(label: '0', onTap: () => _onDigit('0')),
                        _PadButton(
                          icon: Icons.backspace_outlined,
                          onTap: _onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _PadButton({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: SizedBox(
            width: 78,
            height: 60,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 26)
                  : Text(
                      label ?? '',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
