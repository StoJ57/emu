import 'package:flutter/material.dart';

import 'audio.dart';
import 'song.dart';

class AlbumPage extends StatelessWidget {
  final int albumId;
  const AlbumPage(this.albumId, {super.key});

  @override
  Widget build(BuildContext context) {
    var album = AlbumManager.albums[albumId];

    var songs = album.getSongs();

    TextButton libraryButton;
    if (AlbumManager.library.contains(album)) {
      libraryButton = TextButton(
          onPressed: () {
            AlbumManager.library.remove(album);
            AlbumManager.writeLibrary();
          },
          child: const Text('Remove from library'));
    } else {
      libraryButton = TextButton(
          onPressed: () {
            AlbumManager.library.add(album);
            AlbumManager.writeLibrary();
          },
          child: const Text('Add to library'));
    }

    List<Widget> listTiles = [
      TextButton(
          onPressed: () {
            PlaybackManager.playAlbum(album, 0);
          },
          child: const Text('Play All')),
      TextButton(
          onPressed: () {
            PlaybackManager.playAlbumShuffled(album);
          },
          child: const Text('Shuffle Play')),
      libraryButton
    ];

    var i = 0;
    for (var song in songs) {
      int iLocal = i;

      listTiles.add(ListTile(
        title: Text(song.name),
        subtitle: Text(song.getSubtitle()),
        onTap: () {
          PlaybackManager.playAlbum(AlbumManager.albums[albumId], iLocal);
        },
      ));
      i += 1;
    }

    return Scaffold(
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(AlbumManager.albums[albumId].name),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            )),
        body: ListView(
            children: ListTile.divideTiles(tiles: listTiles, context: context)
                .toList()),
        bottomNavigationBar: const SongBar());
  }
}
