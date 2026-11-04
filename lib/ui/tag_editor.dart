import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/permissions.dart';
import '../state/library_state.dart';

/// Tag editor: reads the file's tags, lets the user edit them, writes them
/// back to the file, then re-indexes it. Artwork, lyrics and BPM already in
/// the file are preserved (AudioTags.write replaces all metadata).
class TagEditorScreen extends StatefulWidget {
  const TagEditorScreen({super.key, required this.song});

  final Song song;

  @override
  State<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends State<TagEditorScreen> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _album = TextEditingController();
  final _albumArtist = TextEditingController();
  final _genre = TextEditingController();
  final _year = TextEditingController();
  final _track = TextEditingController();
  final _trackTotal = TextEditingController();
  final _disc = TextEditingController();
  final _discTotal = TextEditingController();

  Tag? _original;
  bool _loading = true;
  bool _saving = false;
  bool _removeArtwork = false;
  String? _error;

  List<TextEditingController> get _all => [
        _title, _artist, _album, _albumArtist, _genre, //
        _year, _track, _trackTotal, _disc, _discTotal,
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = widget.song;
    try {
      final tag = await AudioTags.read(s.data);
      _original = tag;
      _title.text = tag?.title ?? s.title;
      _artist.text = tag?.trackArtist ?? s.artist;
      _album.text = tag?.album ?? s.album;
      _albumArtist.text = tag?.albumArtist ?? s.albumArtist;
      _genre.text = tag?.genre ?? s.genre;
      _year.text = _num(tag?.year ?? (s.year == 0 ? null : s.year));
      _track.text = _num(tag?.trackNumber ?? (s.track == 0 ? null : s.track));
      _trackTotal.text = _num(tag?.trackTotal);
      _disc.text = _num(tag?.discNumber);
      _discTotal.text = _num(tag?.discTotal);
    } catch (e) {
      // Fall back to what MediaStore knows; saving may still work.
      _title.text = s.title;
      _artist.text = s.artist;
      _album.text = s.album;
      _albumArtist.text = s.albumArtist;
      _genre.text = s.genre;
      _year.text = _num(s.year == 0 ? null : s.year);
      _track.text = _num(s.track == 0 ? null : s.track);
      _error = 'Could not read existing tags: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  static String _num(int? v) => v == null || v == 0 ? '' : '$v';
  static int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  static String? _str(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final library = context.read<LibraryState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Writing arbitrary files needs All files access on Android 11+.
      if (!await MediaPermissions.hasAllFilesAccess) {
        await MediaPermissions.requestAllFilesAccess();
      }

      final old = _original;
      final tag = Tag(
        title: _str(_title),
        trackArtist: _str(_artist),
        album: _str(_album),
        albumArtist: _str(_albumArtist),
        genre: _str(_genre),
        year: _int(_year),
        trackNumber: _int(_track),
        trackTotal: _int(_trackTotal),
        discNumber: _int(_disc),
        discTotal: _int(_discTotal),
        lyrics: old?.lyrics,
        bpm: old?.bpm,
        pictures: _removeArtwork ? const [] : (old?.pictures ?? const []),
      );

      await AudioTags.write(widget.song.data, tag);
      await library.rescanFile(widget.song.data);

      messenger.showSnackBar(const SnackBar(content: Text('Tags saved')));
      navigator.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save tags: $e';
        });
      }
    }
  }

  Widget _field(String label, TextEditingController c,
      {bool number = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: !_saving,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        textCapitalization:
            number ? TextCapitalization.none : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasArt = (_original?.pictures.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag editor'),
        actions: [
          TextButton(
            onPressed: _loading || _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.song.data,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                _field('Title', _title, icon: Icons.title),
                _field('Artist', _artist, icon: Icons.person_outline),
                _field('Album', _album, icon: Icons.album_outlined),
                _field('Album artist', _albumArtist, icon: Icons.people_outline),
                _field('Genre', _genre, icon: Icons.category_outlined),
                _field('Year', _year, number: true, icon: Icons.event_outlined),
                Row(
                  children: [
                    Expanded(child: _field('Track', _track, number: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('of', _trackTotal, number: true)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _field('Disc', _disc, number: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('of', _discTotal, number: true)),
                  ],
                ),
                if (hasArt)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remove embedded artwork'),
                    value: _removeArtwork,
                    onChanged:
                        _saving ? null : (v) => setState(() => _removeArtwork = v),
                  ),
              ],
            ),
    );
  }
}
