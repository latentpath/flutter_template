import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/widgets/async_status.dart';
import '../../core/logging/app_logger.dart';
import '../../l10n/generated/app_localizations.dart';
import 'example_repository.dart';

final exampleRepositoryProvider = Provider<ExampleRepository>(
  (ref) => throw StateError('Example repository not configured'),
);

final exampleLoggerProvider = Provider<AppLogger>((ref) => AppLogger());

final exampleItemsProvider = FutureProvider.autoDispose<List<ExampleItem>>((
  ref,
) {
  final cancellation = ExampleCancellation();
  ref.onDispose(cancellation.cancel);
  return ref.watch(exampleRepositoryProvider).fetch(cancellation);
});

class ExamplePage extends ConsumerWidget {
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final result = ref.watch(exampleItemsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.exampleTitle)),
      body: Center(
        child: result.when(
          loading: () => LoadingStatus(label: l.loading),
          error: (error, _) {
            final kind = error is AppException
                ? error.failure.kind
                : AppFailureKind.unknown;
            if (kind == AppFailureKind.cancelled) {
              return const SizedBox.shrink();
            }
            ref.read(exampleLoggerProvider).record(DiagnosticEvent.errorView);
            final message = switch (kind) {
              AppFailureKind.timeout => l.errorTimeout,
              AppFailureKind.connection => l.errorConnection,
              AppFailureKind.unauthorized ||
              AppFailureKind.forbidden => l.errorAccess,
              AppFailureKind.notFound => l.errorNotFound,
              AppFailureKind.rateLimited => l.errorRateLimited,
              AppFailureKind.server => l.errorServer,
              AppFailureKind.invalidResponse => l.errorInvalidResponse,
              _ => l.exampleError,
            };
            return ErrorStatus(
              message: message,
              retryLabel: l.retry,
              onRetry: () => ref.invalidate(exampleItemsProvider),
            );
          },
          data: (items) => items.isEmpty
              ? EmptyStatus(message: l.exampleEmpty)
              : ListView(
                  children: [
                    for (final item in items) ListTile(title: Text(item.title)),
                  ],
                ),
        ),
      ),
    );
  }
}
