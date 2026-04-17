import 'package:flutter/material.dart';

void main() {
  runApp(const LinkedInExportViewerApp());
}

class LinkedInExportViewerApp extends StatelessWidget {
  const LinkedInExportViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkedIn Export Viewer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A66C2)),
      ),
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LinkedIn Export Viewer', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Bootstrap scaffold — real UI lands in Phase 1.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
