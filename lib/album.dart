import 'package:flutter/material.dart';

import 'audio.dart';
import 'song.dart';

class AlbumPage extends StatefulWidget {
  final int albumId;
  final Function? onUpdate;

  const AlbumPage(this.albumId, this.onUpdate, {super.key});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  void updated() {
    if (widget.onUpdate != null) {
      widget.onUpdate!();
    }
  }

  @override
  Widget build(BuildContext context) {
    var album = AlbumManager.albums[widget.albumId];

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
            setState(() {
              PlaybackManager.playAlbum(album, 0);
            });
            updated();
          },
          child: const Text('Play All')),
      TextButton(
          onPressed: () {
            setState(() {
              PlaybackManager.playAlbumShuffled(album);
            });
            updated();
          },
          child: const Text('Shuffle Play')),
      libraryButton
    ];

    var i = 0;
    for (var playable in album.include) {
      int iLocal = i;
      if (playable is Album) {
        Album subAlbum = playable;
        listTiles.add(ListTile(
          leading: subAlbum.isPlaying()
              ? const Icon(Icons.equalizer)
              : InkWell(
                  child: const Icon(Icons.playlist_play),
                  onTap: () {
                    setState(() {
                      PlaybackManager.playAlbum(album, iLocal);
                    });
                    updated();
                  }),
          selected: subAlbum.isPlaying(),
          title: Text(subAlbum.name),
          subtitle: Text(subAlbum.getSubtitle()),
          onTap: () {
            var subAlbumId = AlbumManager.albums.indexOf(subAlbum);
            if (subAlbumId == -1) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Please wait for albums to load')));
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                return AlbumPage(subAlbumId, () {
                  setState(() {});
                });
              }),
            );
          },
        ));
        i += subAlbum.getSongs().length;
      } else if (playable is Song) {
        Song song = playable;
        var playing = false;
        if (PlaybackManager.currentSong() != null &&
            PlaybackManager.currentSong()! == song) {
          playing = true;
        }
        listTiles.add(ListTile(
          leading: playing
              ? const Icon(Icons.equalizer)
              : const Icon(Icons.play_arrow),
          title: Text(song.name),
          selected: playing,
          subtitle: Text(song.getSubtitle()),
          onTap: () {
            setState(() {
              if (playing) {
              } else {
                PlaybackManager.playAlbum(album, iLocal);
              }
            });
            updated();
          },
        ));
        i += 1;
      }
    }

    return Scaffold(
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(AlbumManager.albums[widget.albumId].name),
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
