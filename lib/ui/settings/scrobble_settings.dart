import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/scrobbler.dart';

class ScrobbleSettingsScreen extends StatefulWidget {
  const ScrobbleSettingsScreen({super.key});

  @override
  State<ScrobbleSettingsScreen> createState() => _ScrobbleSettingsScreenState();
}

class _ScrobbleSettingsScreenState extends State<ScrobbleSettingsScreen> {
  late final TextEditingController _lbToken;
  late final TextEditingController _lfmKey;
  late final TextEditingController _lfmSecret;
  final TextEditingController _lfmUser = TextEditingController();
  final TextEditingController _lfmPass = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<Scrobbler>();
    _lbToken = TextEditingController(text: s.lbToken);
    _lfmKey = TextEditingController(text: s.lfmKey);
    _lfmSecret = TextEditingController(text: s.lfmSecret);
    _lfmUser.text = s.lfmUser;
  }

  @override
  void dispose() {
    _lbToken.dispose();
    _lfmKey.dispose();
    _lfmSecret.dispose();
    _lfmUser.dispose();
    _lfmPass.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Scrobbler>();
    final title = Theme.of(context).textTheme.titleMedium;
    final signedIn = s.lfmSession.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Scrobbling')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ListenBrainz', style: title),
          const SizedBox(height: 8),
          TextField(
            controller: _lbToken,
            decoration: const InputDecoration(
              labelText: 'User token',
              helperText: 'Find it at listenbrainz.org/settings',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => s.lbToken = v.trim(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Scrobble to ListenBrainz'),
            value: s.lbEnabled,
            onChanged: (v) => s.lbEnabled = v,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _busy || s.lbToken.isEmpty
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final user = await s.lbValidate(s.lbToken);
                      if (!mounted) return;
                      setState(() => _busy = false);
                      _snack(user == null ? 'Invalid token' : 'Valid token for $user');
                    },
              child: const Text('Validate token'),
            ),
          ),
          const Divider(height: 40),
          Text('Last.fm', style: title),
          const SizedBox(height: 4),
          Text(
            'Create a free API account at last.fm/api/account/create and paste its key and secret.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lfmKey,
            decoration: const InputDecoration(
              labelText: 'API key',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => s.lfmKey = v.trim(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lfmSecret,
            decoration: const InputDecoration(
              labelText: 'Shared secret',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => s.lfmSecret = v.trim(),
          ),
          const SizedBox(height: 12),
          if (signedIn) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text('Signed in as ${s.lfmUser}'),
              trailing: TextButton(
                onPressed: s.lfmSignOut,
                child: const Text('Sign out'),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scrobble to Last.fm'),
              value: s.lfmEnabled,
              onChanged: (v) => s.lfmEnabled = v,
            ),
          ] else ...[
            TextField(
              controller: _lfmUser,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lfmPass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'Only used to get a session key; it is not stored',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final error =
                            await s.lfmLogin(_lfmUser.text.trim(), _lfmPass.text);
                        if (!mounted) return;
                        setState(() => _busy = false);
                        _lfmPass.clear();
                        _snack(error ?? 'Signed in');
                      },
                child: const Text('Sign in'),
              ),
            ),
          ],
          const Divider(height: 40),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${s.pendingCount} scrobbles waiting to be sent'),
            trailing: TextButton(
              onPressed: () async {
                await s.flush();
                if (mounted) _snack('Done');
              },
              child: const Text('Send now'),
            ),
          ),
        ],
      ),
    );
  }
}
