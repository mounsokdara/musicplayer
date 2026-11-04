import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/library_state.dart';

class LibraryFiltersScreen extends StatelessWidget {
  const LibraryFiltersScreen({super.key});

  Future<void> _pick(
    BuildContext context,
    Set<String> exclude,
    void Function(String) onPick,
  ) async {
    final library = context.read<LibraryState>();
    final options = library.allFolders.where((f) => !exclude.contains(f)).toList()
      ..sort();
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose a folder'),
        children: [
          SizedBox(
            width: double.maxFinite,
            height: 360,
            child: options.isEmpty
                ? const Center(child: Text('No more folders'))
                : ListView(
                    children: [
                      for (final f in options)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(f.split('/').last),
                          subtitle: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(dialogContext, f),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
    if (choice != null) onPick(choice);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final white = library.whitelistedFolders.toList()..sort();
    final black = library.blacklistedFolders.toList()..sort();
    final header = Theme.of(context).textTheme.titleSmall;

    return Scaffold(
      appBar: AppBar(title: const Text('Folder filters')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Whitelist mode'),
            subtitle: const Text('Only show songs inside whitelisted folders'),
            value: library.useWhitelist,
            onChanged: library.setUseWhitelist,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Whitelist', style: header),
          ),
          for (final f in white)
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(f.split('/').last),
              subtitle: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => library.unwhitelistFolder(f),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add folder to whitelist'),
            onTap: () => _pick(
              context,
              library.whitelistedFolders,
              library.whitelistFolder,
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Blacklist', style: header),
          ),
          for (final f in black)
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(f.split('/').last),
              subtitle: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => library.unblacklistFolder(f),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add folder to blacklist'),
            onTap: () => _pick(
              context,
              library.blacklistedFolders,
              library.blacklistFolder,
            ),
          ),
        ],
      ),
    );
  }
}
