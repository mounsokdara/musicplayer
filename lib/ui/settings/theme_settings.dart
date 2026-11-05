import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/material_you.dart';
import '../../services/settings_service.dart';

/// Theme page (same layout as the Video Player app): appearance mode,
/// dynamic color, Material You color chips, custom color, pure black.
class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsService>();
    final pad = MediaQuery.viewPaddingOf(context);
    final scheme = Theme.of(context).colorScheme;
    final label = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        );

    final rgb = s.accentColor.toARGB32() & 0xFFFFFF;
    final isCustom = !s.useDynamicColor &&
        !schemeChips.any((c) => (c.circle.toARGB32() & 0xFFFFFF) == rgb);

    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + pad.bottom),
        children: [
          Text('Appearance', style: label),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('Auto'),
              ),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.themeMode = v.first,
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dynamic color'),
            subtitle: const Text(
                'Use wallpaper colors when the device supports Material You'),
            value: s.useDynamicColor,
            onChanged: (v) => s.useDynamicColor = v,
          ),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: s.useDynamicColor,
            child: Opacity(
              opacity: s.useDynamicColor ? 0.38 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Material You color', style: label),
                  const SizedBox(height: 4),
                  MaterialYouChips(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    selected: s.accentColor,
                    onPick: (c) {
                      s.accentColor = c.circle;
                      s.useDynamicColor = false;
                    },
                  ),
                  ListTile(
                    contentPadding: isCustom
                        ? const EdgeInsets.symmetric(horizontal: 12)
                        : EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isCustom
                          ? BorderSide(color: scheme.primary, width: 2)
                          : BorderSide.none,
                    ),
                    selected: isCustom,
                    selectedTileColor:
                        scheme.primaryContainer.withValues(alpha: 0.5),
                    leading: CircleAvatar(backgroundColor: s.accentColor),
                    title: const Text('Custom color'),
                    subtitle: Text(
                      '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}',
                    ),
                    trailing: Icon(
                      isCustom ? Icons.check_circle : Icons.chevron_right,
                    ),
                    onTap: () async {
                      final picked =
                          await showColorPicker(context, s.accentColor);
                      if (picked != null) {
                        s.accentColor = picked;
                        s.useDynamicColor = false;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Display', style: label),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pure black dark theme'),
            subtitle: const Text('True black backgrounds, saves power on OLED'),
            value: s.amoledBlack,
            onChanged: (v) => s.amoledBlack = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('High contrast'),
            subtitle: const Text('Stronger outlines and text colors'),
            value: s.highContrast,
            onChanged: (v) => s.highContrast = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bold text'),
            subtitle: const Text('Heavier titles and list text'),
            value: s.boldText,
            onChanged: (v) => s.boldText = v,
          ),
        ],
      ),
    );
  }
}

Future<Color?> showColorPicker(BuildContext context, Color initial) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _ColorPickerSheet(initial: initial),
    ),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial});
  final Color initial;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor hsv;
  late final TextEditingController hex;

  @override
  void initState() {
    super.initState();
    hsv = HSVColor.fromColor(widget.initial.withValues(alpha: 1));
    hex = TextEditingController(text: _hexOf(hsv.toColor()));
  }

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  String _hexOf(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  void _set(HSVColor next, {bool syncHex = true}) {
    setState(() => hsv = next);
    if (syncHex) {
      hex.value = TextEditingValue(
        text: _hexOf(next.toColor()),
        selection: const TextSelection.collapsed(offset: 6),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = hsv.toColor();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Custom color',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: hex,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      prefixText: '#',
                      counterText: '',
                      labelText: 'Hex',
                    ),
                    onChanged: (v) {
                      final raw = v.replaceAll('#', '').trim();
                      if (raw.length != 6) return;
                      final n = int.tryParse(raw, radix: 16);
                      if (n == null) return;
                      _set(HSVColor.fromColor(Color(0xFF000000 | n)),
                          syncHex: false);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _labeled('Hue', hsv.hue, 0, 360, (v) => _set(hsv.withHue(v))),
            _labeled('Saturation', hsv.saturation, 0, 1,
                (v) => _set(hsv.withSaturation(v))),
            _labeled(
                'Brightness', hsv.value, 0, 1, (v) => _set(hsv.withValue(v))),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, color),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeled(String label, double value, double min, double max,
      ValueChanged<double> on) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Slider(
          min: min,
          max: max,
          value: value.clamp(min, max).toDouble(),
          onChanged: on,
        ),
      ],
    );
  }
}
