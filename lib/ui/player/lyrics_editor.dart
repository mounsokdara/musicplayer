import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../services/lyrics/lyrics_service.dart';
import '../../state/player_state.dart';

class LyricsEditorScreen extends StatefulWidget {
  const LyricsEditorScreen({super.key, required this.song});

  final Song song;

  @override
  State<LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends State<LyricsEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final text = await LyricsService.storedText(widget.song);
    if (!mounted) return;
    setState(() {
      _controller.text = text ?? '';
      _loading = false;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    final text = await LyricsService.download(widget.song);
    if (!mounted) return;
    setState(() => _busy = false);
    if (text == null) {
      _snack('No lyrics found online');
      return;
    }
    setState(() => _controller.text = text);
  }

  Future<void> _save() async {
    final player = context.read<PlayerState>();
    final text = _controller.text.trim();
    if (text.isEmpty) {
      await LyricsService.delete(widget.song);
    } else {
      await LyricsService.save(widget.song, text);
    }
    await player.refreshLyrics(widget.song);
    if (mounted) Navigator.pop(context);
  }

  String _stamp(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '[$m:$s.$cs]';
  }

  void _insertStamp() {
    final player = context.read<PlayerState>();
    final stamp = _stamp(player.position);
    final sel = _controller.selection;
    final pos = sel.isValid ? sel.start : _controller.text.length;
    _controller.value = _controller.value.copyWith(
      text: _controller.text.replaceRange(pos, pos, stamp),
      selection: TextSelection.collapsed(offset: pos + stamp.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final canStamp = player.current?.id == widget.song.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Download from LRCLIB',
            onPressed: _busy ? null : _download,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _controller,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            '[00:12.50] Line of lyrics\n[00:15.00] <00:15.00>Word <00:15.40>by <00:15.80>word\n\nUse the same timestamp twice for a translation line. TTML is also supported.',
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: canStamp ? _insertStamp : null,
                            icon: const Icon(Icons.schedule),
                            label: const Text('Insert timestamp'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
