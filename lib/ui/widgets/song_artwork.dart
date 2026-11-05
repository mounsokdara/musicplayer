import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Square (1:1) artwork, never stretched.
class SongArtwork extends StatelessWidget {
  const SongArtwork({
    super.key,
    required this.id,
    this.size = 52,
    this.type = ArtworkType.AUDIO,
    this.radius = 10,
    this.highRes = false,
  });

  final int id;
  final double size;
  final ArtworkType type;
  final double radius;

  /// Large views (Now Playing) request a bigger, sharper bitmap.
  final bool highRes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: QueryArtworkWidget(
          id: id,
          type: type,
          artworkFit: BoxFit.cover,
          size: highRes ? 1000 : 200,
          quality: highRes ? 100 : 50,
          artworkQuality: highRes ? FilterQuality.high : FilterQuality.low,
          artworkWidth: size,
          artworkHeight: size,
          artworkBorder: BorderRadius.circular(radius),
          keepOldArtwork: true,
          nullArtworkWidget: Container(
            color: scheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
