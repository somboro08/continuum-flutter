import 'dart:async';
import 'dart:io';

import 'package:continuum_navigation_flutter/continuum_navigation_flutter.dart';
import 'package:continuum_navigation_recovery/continuum_navigation_recovery.dart';
import 'package:continuum_persistence/continuum_persistence.dart';
import 'package:continuum_recovery/continuum_recovery.dart';
import 'package:continuum_storage_file/continuum_storage_file.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDirectory = await getApplicationSupportDirectory();
  final store = FileContinuumStore(
    directory: Directory('${supportDirectory.path}/continuum-navigation-demo'),
  );
  final environment = createExampleEnvironment(store: store);
  runApp(ContinuumNavigationExampleApp(environment: environment));
}

/// Creates the complete demo composition with an application-owned store.
///
/// Tests can supply InMemoryContinuumStore; the runnable app supplies the
/// durable FileContinuumStore adapter.
ExampleEnvironment createExampleEnvironment({
  required ContinuumStore store,
}) {
  final recovery = RecoveryCoordinator(
    store: store,
    namespace: 'continuum.navigation.example',
  );

  late final NavigatorPagesAdapter navigation;
  navigation = NavigatorPagesAdapter(
    pageRegistry: NavigationPageRegistry({
      'home': (_) => _ExamplePage(
            key: const ValueKey<String>('home'),
            builder: (_) => _DemoScreen(
              title: 'Continuum Navigation',
              message:
                  'Cette page est sauvegardée. Ouvre le détail, puis ferme et '
                  'relance l’application pour observer la restauration.',
              actionLabel: 'Voir le détail',
              onAction: () => _openDetails(navigation, recovery),
            ),
          ),
      'details': (entry) => _ExamplePage(
            key: ValueKey<String>('details-${entry.parameters['itemId']}'),
            builder: (context) => _DemoScreen(
              title: 'Détail restaurable',
              message:
                  'Identifiant : ${entry.parameters['itemId']}. '
                  'Cette route et son identifiant sont autorisés dans le '
                  'snapshot de navigation.',
              actionLabel: 'Retour à l’accueil',
              onAction: () async {
                await Navigator.of(context).maybePop();
              },
            ),
          ),
    }),
  );

  recovery.register(
    NavigationRecoveryParticipant(
      recoveryId: 'demo.navigation',
      state: navigation,
      routes: NavigationRouteRegistry([
        NavigationRouteDefinition(routeId: 'home'),
        NavigationRouteDefinition(
          routeId: 'details',
          persistedParameterKeys: {'itemId'},
          validateParameters: (parameters) =>
              parameters['itemId'] is String,
        ),
      ]),
      schema: NavigationRecoverySchema(version: 1),
    ),
  );

  return ExampleEnvironment(navigation: navigation, recovery: recovery);
}

Future<void> _openDetails(
  NavigatorPagesAdapter navigation,
  RecoveryCoordinator recovery,
) async {
  await navigation.replaceStack([
    NavigationEntry(routeId: 'home'),
    NavigationEntry(
      routeId: 'details',
      parameters: const {'itemId': 'demo-42'},
    ),
  ]);
  await recovery.checkpoint();
}

class ExampleEnvironment {
  const ExampleEnvironment({
    required this.navigation,
    required this.recovery,
  });

  final NavigatorPagesAdapter navigation;
  final RecoveryCoordinator recovery;

  void dispose() => navigation.dispose();
}

class ContinuumNavigationExampleApp extends StatefulWidget {
  const ContinuumNavigationExampleApp({
    super.key,
    required this.environment,
  });

  final ExampleEnvironment environment;

  @override
  State<ContinuumNavigationExampleApp> createState() =>
      _ContinuumNavigationExampleAppState();
}

class _ContinuumNavigationExampleAppState
    extends State<ContinuumNavigationExampleApp> {
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _restoreNavigation();
  }

  Future<void> _restoreNavigation() async {
    final result = await widget.environment.recovery.recover();
    if (result.failed.isNotEmpty) {
      final failure = result.failed.values.first;
      throw StateError(
        'Navigation recovery failed at ${failure.stage.name}: '
        '${failure.error}',
      );
    }

    if (result.missing.contains('demo.navigation')) {
      await widget.environment.navigation.replaceStack([
        NavigationEntry(routeId: 'home'),
      ]);
      await widget.environment.recovery.checkpoint();
    }
  }

  Future<void> _checkpointAfterPop() async {
    try {
      final result = await widget.environment.recovery.checkpoint();
      if (!result.isSuccessful) {
        debugPrint('Continuum checkpoint failures: ${result.failed}');
      }
    } catch (error, stackTrace) {
      debugPrint('Continuum checkpoint error: $error\n$stackTrace');
    }
  }

  @override
  void dispose() {
    widget.environment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFF202124),
          fontSize: 16,
        ),
        child: FutureBuilder<void>(
          future: _ready,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StatusScreen(
                message: 'Impossible de restaurer la navigation : '
                    '${snapshot.error}',
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const _StatusScreen(
                message: 'Restauration de la navigation…',
              );
            }

            return AnimatedBuilder(
              animation: widget.environment.navigation,
              builder: (context, _) => Navigator(
                pages: widget.environment.navigation.pages,
                onDidRemovePage: (page) {
                  if (widget.environment.navigation.handlePageRemoved(page)) {
                    unawaited(_checkpointAfterPop());
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExamplePage extends Page<void> {
  const _ExamplePage({
    super.key,
    required this.builder,
  });

  final WidgetBuilder builder;

  @override
  Route<void> createRoute(BuildContext context) {
    return PageRouteBuilder<void>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    );
  }
}

class _DemoScreen extends StatelessWidget {
  const _DemoScreen({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F5F8),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      height: 1.5,
                      color: Color(0xFF555B65),
                    ),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => unawaited(onAction()),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF202124),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Text(
                          actionLabel,
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F5F8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message),
        ),
      ),
    );
  }
}
