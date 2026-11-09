import 'package:flutter/material.dart';

class LoadingStatus extends StatelessWidget {
  const LoadingStatus({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) =>
      Semantics(label: label, child: const CircularProgressIndicator());
}

class EmptyStatus extends StatelessWidget {
  const EmptyStatus({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) =>
      Text(message, textAlign: TextAlign.center);
}

class ErrorStatus extends StatelessWidget {
  const ErrorStatus({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    ),
  );
}
