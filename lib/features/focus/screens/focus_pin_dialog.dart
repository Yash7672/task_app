import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';

class FocusPinDialog extends ConsumerStatefulWidget {
  const FocusPinDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FocusPinDialog(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<FocusPinDialog> createState() => _FocusPinDialogState();
}

class _FocusPinDialogState extends ConsumerState<FocusPinDialog> {
  String _buffer = '';
  String? _errorText;
  bool _verifying = false;

  void _onDigit(String digit) {
    if (_verifying || _buffer.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _errorText = null;
      _buffer += digit;
    });
    if (_buffer.length == 4) {
      _verify(_buffer);
    }
  }

  void _onBackspace() {
    if (_verifying || _buffer.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _errorText = null;
      _buffer = _buffer.substring(0, _buffer.length - 1);
    });
  }

  Future<void> _verify(String pin) async {
    setState(() => _verifying = true);
    final valid = await ref.read(focusProvider.notifier).verifyPinForExit(pin);
    if (!mounted) return;
    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _verifying = false;
        _errorText = 'Incorrect PIN';
        _buffer = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.lock_outline_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Enter PYLO PIN to end focus',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
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
                    color: filled
                        ? (_errorText != null
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary)
                        : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? (_errorText != null
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary)
                          : theme.colorScheme.outline,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
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
                          .map((d) => _PinButton(
                              label: d,
                              onTap: () => _onDigit(d),
                              enabled: !_verifying))
                          .toList(),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(5),
                        child: SizedBox(width: 78, height: 60),
                      ),
                      _PinButton(
                          label: '0',
                          onTap: () => _onDigit('0'),
                          enabled: !_verifying),
                      _PinButton(
                        icon: Icons.backspace_outlined,
                        onTap: _onBackspace,
                        enabled: !_verifying,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _verifying
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PinButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool enabled;

  const _PinButton({
    this.label,
    this.icon,
    required this.onTap,
    this.enabled = true,
  });

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
          onTap: enabled ? onTap : null,
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
