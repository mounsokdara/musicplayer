import 'dart:io';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../services/artist_images.dart';
import 'song_artwork.dart';

class ArtistImage extends StatefulWidget {
  const ArtistImage({
    super.key,
    required this.id,
    required this.name,
    this.size = 52,
    this.radius = 10,
  });

  final int id;
  final String name;
  final double size;
  final double radius;

  @override
  State<ArtistImage> createState() => _ArtistImageState();
}

class _ArtistImageState extends State<ArtistImage> {
  late Future<File?> _file = ArtistImages.fetch(widget.name);

  @override
  void didUpdateWidget(covariant ArtistImage old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _file = ArtistImages.fetch(widget.name);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snap) {
        final file = snap.data;
        if (file == null) {
          return SongArtwork(
            id: widget.id,
            type: ArtworkType.ARTIST,
            size: widget.size,
            radius: widget.radius,
          );
        }
        return SizedBox.square(
          dimension: widget.size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SongArtwork(
                id: widget.id,
                type: ArtworkType.ARTIST,
                size: widget.size,
                radius: widget.radius,
              ),
            ),
          ),
        );
      },
    );
  }
}
