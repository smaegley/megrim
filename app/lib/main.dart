import 'package:flutter/material.dart';

import 'theme.dart';

void main() {
  runApp(const MegrimApp());
}

class MegrimApp extends StatelessWidget {
  const MegrimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Megrim',
      debugShowCheckedModeBanner: false,
      theme: megrimDarkTheme(),
      home: const _ScaffoldPlaceholder(),
    );
  }
}

// Phase 0 placeholder home. Replaced by the real navigation shell in Phase 1.
class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Megrim')),
      body: const Center(
        child: Text('Migraine diary — scaffolding in progress.'),
      ),
    );
  }
}
