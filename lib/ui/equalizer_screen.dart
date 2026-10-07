import 'package:equalizer_flutter/equalizer_flutter.dart';
import 'package:flutter/material.dart';

/// System equalizer (Android AudioEffect) with bands, presets and bass boost.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  bool _enabled = true;
  List<int> _bands = [];
  List<String> _presets = [];
  String? _preset;
  int _min = -1500;
  int _max = 1500;
  double _bassBoost = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await EqualizerFlutter.init(0);
      final bands = await EqualizerFlutter.getCenterBandFreqs();
      final range = await EqualizerFlutter.getBandLevelRange();
      final presets = await EqualizerFlutter.getPresetNames();
      if (!mounted) return;
      setState(() {
        _bands = bands;
        _min = range.first;
        _max = range.last;
        _presets = presets;
      });
    } catch (_) {
      // Some devices expose no equalizer effect.
    }
  }

  @override
  void dispose() {
    EqualizerFlutter.release();
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
              EqualizerFlutter.setEnabled(v);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _bands.isEmpty
          ? const Center(child: Text('No equalizer available on this device'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _preset,
                  decoration: const InputDecoration(
                    labelText: 'Preset',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final p in _presets)
                      DropdownMenuItem(value: p, child: Text(p)),
                  ],
                  onChanged: _enabled
                      ? (v) {
                          setState(() => _preset = v);
                          if (v != null) EqualizerFlutter.setPreset(v);
                        }
                      : null,
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < _bands.length; i++)
                  _BandSlider(
                    index: i,
                    frequency: _bands[i],
                    min: _min,
                    max: _max,
                    enabled: _enabled,
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
                          EqualizerFlutter.setBandLevel(0, v.round());
                        }
                      : null,
                ),
              ],
            ),
    );
  }
}

class _BandSlider extends StatefulWidget {
  const _BandSlider({
    required this.index,
    required this.frequency,
    required this.min,
    required this.max,
    required this.enabled,
  });

  final int index;
  final int frequency;
  final int min;
  final int max;
  final bool enabled;

  @override
  State<_BandSlider> createState() => _BandSliderState();
}

class _BandSliderState extends State<_BandSlider> {
  double _value = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text('${(widget.frequency / 1000).round()} Hz',
              style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: Slider(
            value: _value.clamp(widget.min.toDouble(), widget.max.toDouble()),
            min: widget.min.toDouble(),
            max: widget.max.toDouble(),
            onChanged: widget.enabled
                ? (v) {
                    setState(() => _value = v);
                    EqualizerFlutter.setBandLevel(widget.index, v.round());
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
