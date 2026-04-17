import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/url_strategy_stub.dart'
    if (dart.library.js_interop) 'core/url_strategy_web.dart';
import 'router/app_router.dart';

void main() {
  configureUrlStrategy();
  runApp(const ProviderScope(child: LinkedInExportViewerApp()));
}

class LinkedInExportViewerApp extends ConsumerWidget {
  const LinkedInExportViewerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'LinkedIn Export Viewer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A66C2)),
      ),
      routerConfig: router,
    );
  }
}
