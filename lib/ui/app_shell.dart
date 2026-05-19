import 'package:flutter/material.dart';

import '../di/service_locator.dart';
import '../domain/models/models.dart';
import '../domain/repositories/repositories.dart';
import '../services/storage/file_store.dart';

class OrganoteApp extends StatelessWidget {
  const OrganoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Organote',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff256f5b)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff64b59e),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _BackendShell(),
    );
  }
}

class _BackendShell extends StatefulWidget {
  const _BackendShell();

  @override
  State<_BackendShell> createState() => _BackendShellState();
}

class _BackendShellState extends State<_BackendShell> {
  late final FileStore _fileStore = getIt<FileStore>();
  late final LibraryRepository _libraryRepository = getIt<LibraryRepository>();

  Future<void> _chooseStorage() async {
    await _fileStore.chooseRootDirectory();
    await _libraryRepository.reload();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StorageStatus>(
      future: _fileStore.getStatus(),
      builder: (context, storageSnapshot) {
        final storage = storageSnapshot.data;
        if (storage == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!storage.isAvailable) {
          return Scaffold(
            appBar: AppBar(title: const Text('Organote')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Storage setup required',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(storage.message ?? 'Choose a storage folder.'),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _chooseStorage,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Choose folder'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return StreamBuilder<LibrarySnapshot>(
          stream: _libraryRepository.watchLibrary(),
          builder: (context, snapshot) {
            final library = snapshot.data ?? const LibrarySnapshot();
            return Scaffold(
              appBar: AppBar(
                title: const Text('Organote'),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(storage.rootLabel ?? 'Storage ready'),
                    ),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _MetricRow(
                    notes: library.notes.length,
                    templates: library.templates.length,
                    compliance: library.complianceSummary.activeCount,
                  ),
                  const SizedBox(height: 24),
                  Text('Notes', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final note in library.notes)
                    ListTile(
                      leading: Text(note.icon ?? '#'),
                      title: Text(note.title),
                      subtitle: Text(note.tags.join(', ')),
                    ),
                  if (library.notes.isEmpty)
                    const ListTile(title: Text('No notes in storage yet')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.notes,
    required this.templates,
    required this.compliance,
  });

  final int notes;
  final int templates;
  final int compliance;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Metric(label: 'Notes', value: notes),
        _Metric(label: 'Templates', value: templates),
        _Metric(label: 'Compliance', value: compliance),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Text('$value', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
