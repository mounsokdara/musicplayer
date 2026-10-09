import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
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
