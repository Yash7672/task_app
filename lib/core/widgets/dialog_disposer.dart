import 'package:flutter/material.dart';

class DisposeOnExit extends StatefulWidget {
  const DisposeOnExit({
    super.key,
    required this.controllers,
    required this.child,
  });

  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<DisposeOnExit> createState() => _DisposeOnExitState();
}

class _DisposeOnExitState extends State<DisposeOnExit> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
