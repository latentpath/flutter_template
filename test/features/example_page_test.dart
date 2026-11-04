import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/core/errors/app_failure.dart';
import 'package:flutter_template/features/example/example_page.dart';
import 'package:flutter_template/features/example/example_repository.dart';
import 'package:flutter_template/l10n/generated/app_localizations.dart';

final class ControlledRepository implements ExampleRepository {
  int calls = 0;
  final requests = <Completer<List<ExampleItem>>>[];
  final cancellations = <ExampleCancellation>[];
  @override
  Future<List<ExampleItem>> fetch(ExampleCancellation cancellation) {
    calls++;
    cancellations.add(cancellation);
    final request = Completer<List<ExampleItem>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  testWidgets('loading, failure and explicit retry; disposal cancels', (
    tester,
  ) async {
    final repository = ControlledRepository();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [exampleRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExamplePage(),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.requests.first.completeError(
      const AppException(AppFailure(AppFailureKind.connection)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Could not connect. Check your connection.'),
      findsOneWidget,
    );
    expect(repository.calls, 1);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(repository.calls, 2);
    repository.requests.last.complete([const ExampleItem('visible')]);
    await tester.pumpAndSettle();
    expect(find.text('visible'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(repository.cancellations.last.isCancelled, isTrue);
  });
  testWidgets('empty response is shown', (tester) async {
    final repository = ControlledRepository();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [exampleRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExamplePage(),
        ),
      ),
    );
    repository.requests.single.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No data available.'), findsOneWidget);
  });
  testWidgets('late older query cannot replace the newer result', (
    tester,
  ) async {
    final repository = ControlledRepository();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [exampleRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExamplePage(),
        ),
      ),
    );
    container.invalidate(exampleItemsProvider);
    await tester.pump();
    expect(repository.calls, 2);
    expect(repository.cancellations.first.isCancelled, isTrue);
    repository.requests.last.complete([const ExampleItem('new')]);
    await tester.pumpAndSettle();
    repository.requests.first.complete([const ExampleItem('old')]);
    await tester.pumpAndSettle();
    expect(find.text('new'), findsOneWidget);
    expect(find.text('old'), findsNothing);
  });

  testWidgets('cancellation is silent', (tester) async {
    final repository = ControlledRepository();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [exampleRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExamplePage(),
        ),
      ),
    );
    repository.requests.single.completeError(
      const AppException(AppFailure(AppFailureKind.cancelled)),
    );
    await tester.pumpAndSettle();
    expect(find.text('无法加载数据。'), findsNothing);
    expect(find.text('重试'), findsNothing);
  });
  testWidgets(
    'Chinese failure text and retry are localized without raw details',
    (tester) async {
      final repository = ControlledRepository();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [exampleRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExamplePage(),
          ),
        ),
      );
      repository.requests.single.completeError(
        AppException(
          const AppFailure(AppFailureKind.timeout),
          cause: StateError('secret-token'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('请求超时。'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.textContaining('secret-token'), findsNothing);
      expect(repository.calls, 1);
    },
  );
}
