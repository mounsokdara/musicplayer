import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/autoeq.dart';
import '../state/player_state.dart';

/// System equalizer (Android AudioEffect) with bands, presets and bass boost,
/// driven through a MethodChannel to the native Equalizer/BassBoost effects.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  static const _channel = MethodChannel('com.mounsokdara.musicplayer/equalizer');

  bool _enabled = true;
  bool _available = false;
  List<int> _bands = [];
  List<String> _presets = [];
  int? _preset;
  int _min = -1500;
  int _max = 1500;
  double _bassBoost = 0;
  late List<double> _levels;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final player = context.read<PlayerState>().handler.player;
      final sessionId = await player.androidAudioSessionId ?? 0;
      final map = await _channel.invokeMapMethod<String, dynamic>(
          'init', {'sessionId': sessionId});
      if (!mounted || map == null) return;
      setState(() {
        _bands = (map['bands'] as List).cast<int>();
        _min = map['min'] as int;
        _max = map['max'] as int;
        _presets = (map['presets'] as List).cast<String>();
        _levels = List.filled(_bands.length, 0);
        _available = _bands.isNotEmpty;
      });
    } catch (_) {
      // Some devices expose no equalizer effect.
    }
  }

  @override
  void dispose() {
    _channel.invokeMethod('release');
    super.dispose();
  }


  void _applyLevels(List<int> levels) {
    for (var i = 0; i < _bands.length && i < levels.length; i++) {
      final v = levels[i].clamp(_min, _max).toInt();
      _levels[i] = v.toDouble();
      _channel.invokeMethod('setBandLevel', {'band': i, 'level': v});
    }
    setState(() => _preset = null);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _importAutoEq() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import AutoEq profile'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Paste ParametricEQ.txt or GraphicEQ.txt contents',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) controller.text = data!.text!;
            },
            child: const Text('Paste'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final profile = AutoEqProfile.parse(text);
    if (profile == null) {
      _snack('Could not read that AutoEq profile');
      return;
    }
    _applyLevels([
      for (final centre in _bands)
        ((profile.gainAt(centre / 1000) + profile.preamp) * 100).round(),
    ]);
    _snack('Profile applied to ${_bands.length} bands');
  }

  Future<Map<String, List<int>>> _profiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('eq_profiles');
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as List).cast<int>()),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _storeProfiles(Map<String, List<int>> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eq_profiles', jsonEncode(profiles));
  }

  Future<void> _saveProfile() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final profiles = await _profiles();
    profiles[name] = [for (final l in _levels) l.round()];
    await _storeProfiles(profiles);
    _snack('Saved "$name"');
  }

  Future<void> _loadProfile() async {
    final profiles = await _profiles();
    if (!mounted) return;
    if (profiles.isEmpty) {
      _snack('No saved profiles yet');
      return;
    }
    final name = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final entry in profiles.entries)
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(entry.key),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    profiles.remove(entry.key);
                    await _storeProfiles(profiles);
                    if (sheet.mounted) Navigator.pop(sheet);
                  },
                ),
                onTap: () => Navigator.pop(sheet, entry.key),
              ),
          ],
        ),
      ),
    );
    if (name == null) return;
    final levels = profiles[name];
    if (levels == null) return;
    if (levels.length != _bands.length) {
      _snack('That profile was saved for a different number of bands');
      return;
    }
    _applyLevels(levels);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          PopupMenuButton<String>(
            enabled: _available,
            onSelected: (v) {
              switch (v) {
                case 'autoeq':
                  _importAutoEq();
                case 'save':
                  _saveProfile();
                case 'load':
                  _loadProfile();
                case 'reset':
                  _applyLevels(List.filled(_bands.length, 0));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'autoeq', child: Text('Import AutoEq profile')),
              PopupMenuItem(value: 'save', child: Text('Save profile')),
              PopupMenuItem(value: 'load', child: Text('Load profile')),
              PopupMenuItem(value: 'reset', child: Text('Reset to flat')),
            ],
          ),
          Switch(
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
              _channel.invokeMethod('setEnabled', {'enabled': v});
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_available
          ? const Center(child: Text('No equalizer available on this device'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _preset,
                  decoration: const InputDecoration(
                    labelText: 'Preset',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var i = 0; i < _presets.length; i++)
                      DropdownMenuItem(value: i, child: Text(_presets[i])),
                  ],
                  onChanged: _enabled
                      ? (v) {
                          setState(() => _preset = v);
                          if (v != null) {
                            _channel.invokeMethod('setPreset', {'preset': v});
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < _bands.length; i++)
                  Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          _bands[i] >= 1000000
                              ? '${(_bands[i] / 1000000).toStringAsFixed(1)} kHz'
                              : '${(_bands[i] / 1000).round()} Hz',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _levels[i]
                              .clamp(_min.toDouble(), _max.toDouble()),
                          min: _min.toDouble(),
                          max: _max.toDouble(),
                          onChanged: _enabled
                              ? (v) {
                                  setState(() => _levels[i] = v);
                                  _channel.invokeMethod('setBandLevel',
                                      {'band': i, 'level': v.round()});
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                const Divider(height: 32),
                Text('Bass boost',
                    style: Theme.of(context).textTheme.titleMedium),
                Slider(
                  value: _bassBoost,
                  max: 1000,
                  onChanged: _enabled
                      ? (v) {
                          setState(() => _bassBoost = v);
                          _channel.invokeMethod('setBassBoost',
                              {'strength': v.round()});
                        }
                      : null,
                ),
              ],
            ),
    );
  }
}
