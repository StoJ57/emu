import 'dart:async';

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

enum DownloadState {
  unknown,
  undownloaded,
  downloading,
  partial,
  deleting,
  downloaded;

  bool needsPoll() {
    switch (this) {
      case DownloadState.unknown:
      case DownloadState.downloading:
        return true;
      case _:
        return false;
    }
  }
}

class _AlbumPageState extends State<AlbumPage> {
  DownloadState downloadState = DownloadState.unknown;
  int downloadedNum = 0;

  void updated() {
    if (widget.onUpdate != null) {
      widget.onUpdate!();
    }
  }

  @override
  Widget build(BuildContext context) {
    var album = AlbumManager.albums[widget.albumId];

    ElevatedButton libraryButton;
    if (AlbumManager.library.contains(album)) {
      libraryButton = ElevatedButton(
          onPressed: () {
            AlbumManager.library.remove(album);
            AlbumManager.writeLibrary();
          },
          child: const Text('Remove from library'));
    } else {
      libraryButton = ElevatedButton(
          onPressed: () {
            AlbumManager.library.add(album);
            AlbumManager.writeLibrary();
          },
          child: const Text('Add to library'));
    }

    // Downloads
    Widget downloadSection;

    if (album.isDownloading()) {
      downloadState = DownloadState.downloading;
      print('downloading');
      print(DownloadManager.downloadQueue);
    }

    switch (downloadState) {
      case DownloadState.unknown:
        album.downloaded().then((numDownloaded) => {
              setState(() {
                if (numDownloaded == album.getSongs().length) {
                  downloadState = DownloadState.downloaded;
                } else if (numDownloaded == 0) {
                  downloadState = DownloadState.undownloaded;
                } else {
                  downloadState = DownloadState.partial;
                  downloadedNum = numDownloaded;
                }
              })
            });
        downloadSection = const SizedBox.shrink();
      case DownloadState.downloaded:
        downloadSection = ElevatedButton(
            onPressed: () {
              setState(() {
                downloadState = DownloadState.deleting;
                album.undownload().then((_) {
                  setState(() {
                    downloadState = DownloadState.undownloaded;
                  });
                });
              });
            },
            child: const Text('Undownload'));
      case DownloadState.undownloaded:
        downloadSection = ElevatedButton(
            onPressed: () {
              setState(() {
                album.download();
                downloadState = DownloadState.downloading;
              });
            },
            child: const Text('Download'));
      case DownloadState.partial:
        downloadSection = Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8.0,
            children: [
              Text(
                  '$downloadedNum / ${album.getSongs().length} songs downloaded'),
              ElevatedButton(
                  onPressed: () {
                    setState(() {
                      downloadState = DownloadState.downloading;
                      album.download();
                    });
                  },
                  child: const Text('Download all')),
              ElevatedButton(
                  onPressed: () {
                    setState(() {
                      downloadState = DownloadState.deleting;
                      album.undownload().then((_) {
                        setState(() {
                          downloadState = DownloadState.undownloaded;
                        });
                      });
                    });
                  },
                  child: const Text('Undownload all'))
            ]);
      case DownloadState.downloading:
        downloadSection =
            Text('Downloading ($downloadedNum / ${album.getSongs().length})');
        Timer(const Duration(seconds: 1), () {
          album.downloaded().then((numDownloaded) => {
                if (mounted)
                  {
                    setState(() {
                      downloadedNum = numDownloaded;
                      if (downloadedNum == album.getSongs().length) {
                        downloadState = DownloadState.downloaded;
                      }
                    })
                  }
              });
        });
      case DownloadState.deleting:
        downloadSection = const Text('');
    }

    List<Widget> listTiles = [
      Padding(
          padding: const EdgeInsets.all(10.0),
          child: Wrap(
            spacing: 10,
            children: [
              ElevatedButton(
                  onPressed: () {
                    setState(() {
                      PlaybackManager.playAlbum(album, 0);
                    });
                    updated();
                  },
                  child: const Text('Play All')),
              ElevatedButton(
                  onPressed: () {
                    setState(() {
                      PlaybackManager.playAlbumShuffled(album);
                    });
                    updated();
                  },
                  child: const Text('Shuffle Play')),
              libraryButton,
            ],
          )),
      Padding(padding: const EdgeInsets.all(10.0), child: downloadSection)
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
        body: ListView(children: listTiles),
        bottomNavigationBar: const SongBar());
  }
}
