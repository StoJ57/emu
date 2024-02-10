import 'package:flutter/material.dart';
import 'audio.dart';
import 'dart:async';

class SongPage extends StatefulWidget {
  const SongPage({super.key});

  @override
  State<StatefulWidget> createState() => SongPageState();
}

class SongPageState extends State<SongPage> {
  late final StreamSubscription positionStream;

  double progress = 0;
  bool seeking = false;

  @override
  void initState() {
    super.initState();
    positionStream = PlaybackManager.player.stream.position.listen((event) {
      if (!seeking) {
        setState(() {
          if (PlaybackManager.player.state.duration.inMilliseconds == 0) {
            progress = 0;
          } else {
            progress = event.inMilliseconds /
                PlaybackManager.player.state.duration.inMilliseconds;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    positionStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    if (PlaybackManager.isPlaying()) {
      icon = Icons.pause;
    } else {
      icon = Icons.play_arrow;
    }

    Widget image;
    if (PlaybackManager.currentSong()!.artUrl != null) {
      image = Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Image.network(PlaybackManager.currentSong()!.artUrl!.toString()));
    } else {
      image = const SizedBox(height: 50);
    }

    List<Widget> body = [
      const SizedBox(height: 10),
      Text(
        PlaybackManager.currentSong()!.name,
        textScaler: const TextScaler.linear(2.0),
      ),
      const SizedBox(height: 10),
      image,
      Text(PlaybackManager.currentSong()!.getSubtitle()),
      Slider.adaptive(
          value: progress.clamp(0, 1),
          max: 1.0,
          onChangeStart: (value) {
            seeking = true;
          },
          onChangeEnd: (value) async {
            await PlaybackManager.seek(value);
            seeking = false;
          },
          onChanged: (value) {
            setState(() {
              progress = value;
            });
          }),
    ];
    body.add(Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(
        children: [
          IconButton(
            onPressed: () async {
              if (PlaybackManager.hasPrevious()) {
                await PlaybackManager.playPrevious();
              } else {
                await PlaybackManager.seek(0);
              }
              setState(() {});
            },
            icon: const Icon(Icons.skip_previous),
            iconSize: 30.0,
          ),
          IconButton(
              onPressed: () {
                setState(() {
                  if (PlaybackManager.isPlaying()) {
                    PlaybackManager.pause();
                  } else {
                    PlaybackManager.resume();
                  }
                });
              },
              icon: Icon(icon),
              iconSize: 45.0),
          IconButton(
            onPressed: PlaybackManager.hasNext()
                ? () async {
                    try {
                      await PlaybackManager.playNext();
                      setState(() {});
                    } catch (_) {}
                  }
                : null,
            icon: const Icon(Icons.skip_next),
            iconSize: 30.0,
          ),
        ],
      )
    ]));

    return Scaffold(
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Song'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            )),
        body: Padding(
            padding: const EdgeInsets.all(8.0), child: Column(children: body)));
  }
}

class SongBar extends StatefulWidget {
  const SongBar({super.key});

  @override
  State<StatefulWidget> createState() => SongBarState();
}

class SongBarState extends State<SongBar> {
  late final StreamSubscription positionStream;

  double progress = 0;

  @override
  void initState() {
    super.initState();
    positionStream = PlaybackManager.player.stream.position.listen((event) {
      setState(() {
        if (PlaybackManager.player.state.duration.inMilliseconds == 0) {
          progress = 0;
        } else {
          progress = event.inMilliseconds /
              PlaybackManager.player.state.duration.inMilliseconds;
        }
      });
    });
  }

  @override
  void dispose() {
    positionStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PlaybackManager.queue.isEmpty) {
      return const SizedBox.shrink();
    } else {
      IconData icon;
      if (PlaybackManager.isPlaying()) {
        icon = Icons.pause;
      } else {
        icon = Icons.play_arrow;
      }
      return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                return const SongPage();
              }),
            );
          },
          child: Card(
            clipBehavior: Clip.hardEdge,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text(PlaybackManager.currentSong()!.name)),
                IconButton(
                    onPressed: () async {
                      if (PlaybackManager.hasPrevious()) {
                        await PlaybackManager.playPrevious();
                      } else {
                        await PlaybackManager.seek(0);
                      }
                      setState(() {});
                    },
                    icon: const Icon(Icons.skip_previous)),
                IconButton(
                    onPressed: () {
                      setState(() {
                        if (PlaybackManager.isPlaying()) {
                          PlaybackManager.pause();
                        } else {
                          PlaybackManager.resume();
                        }
                      });
                    },
                    icon: Icon(icon)),
                IconButton(
                    onPressed: PlaybackManager.hasNext()
                        ? () async {
                            try {
                              await PlaybackManager.playNext();
                              setState(() {});
                            } catch (_) {}
                          }
                        : null,
                    icon: const Icon(Icons.skip_next)),
              ]),
              LinearProgressIndicator(
                value: progress,
              ),
            ]),
          ));
    }
  }
}
