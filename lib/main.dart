import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  void update() {
    if (PlaybackManager.currentSong() != null) {
      mediaItem.add(PlaybackManager.currentSong()!.toMediaItem());
      List<MediaControl> controls = [MediaControl.skipToPrevious];
      if (PlaybackManager.isPlaying()) {
        controls.add(MediaControl.pause);
      } else {
        controls.add(MediaControl.play);
      }
      if (PlaybackManager.hasNext()) {
        controls.add(MediaControl.skipToNext);
      }
      playbackState.add(playbackState.value.copyWith(
        controls: controls,
        playing: PlaybackManager.isPlaying(),
        processingState: AudioProcessingState.ready,
      ));
    } else {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
      ));
    }
  }

  void update_progress() {
    playbackState.add(playbackState.value.copyWith());
  }

  @override
  Future<void> play() async => await PlaybackManager.resume();

  @override
  Future<void> pause() async => await PlaybackManager.pause();

  @override
  Future<void> skipToNext() async => await PlaybackManager.playNext();

  @override
  Future<void> skipToPrevious() async {
    if (PlaybackManager.hasPrevious()) {
      await PlaybackManager.playPrevious();
    } else {
      await PlaybackManager.seek(0);
    }
  }
}

late AudioPlayerHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.emu.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'mipmap/ic_launcher'),
  );
  runApp(const MyApp());
}

TextEditingController _textFieldController = TextEditingController();

Future<void> _displayTextInputDialog(
    BuildContext context, String name, Function callback) async {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(name),
        content: TextField(
          controller: _textFieldController,
          decoration: InputDecoration(hintText: name),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              callback(_textFieldController.text);
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

class Song {
  Uri url;
  Uri? artUrl;
  String name;
  Song(this.name, this.url, this.artUrl);

  Future<String?> downloaded() async {
    var path = (await AlbumManager.directory).toString();
    path += '/songs';
    path += Uri.encodeComponent(url.toString());
    if (await File.fromUri(Uri.parse(path)).exists()) {
      return path;
    } else {
      return null;
    }
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: url.toString(),
      title: name.toString(),
      artUri: artUrl,
    );
  }
}

class Album {
  String name;
  String path;
  List<Song> include;
  List<Song> exclude;

  Album(this.name, this.include, this.exclude, this.path);

  static Album fromText(String text, String path) {
    var doc = loadYaml(text);
    List<Song> include = [];
    List<Song> exclude = [];
    Uri? art;
    if (doc['art'] != null) {
      art = Uri.parse(doc['art']!);
    }

    if (doc['include'] != null) {
      for (var n in doc['include']) {
        if (n is! YamlMap) {
          throw 'Invalid YAML';
        }
        for (var s in n.entries) {
          include.add(Song(s.key, Uri.parse(s.value), art));
        }
      }
    }
    if (doc['exclude'] != null) {
      // TODO
    }
    return Album(doc['name'], include, exclude, path);
  }

  List<Song> getSongs() {
    return include;
  }

  Future<void> delete() async {
    await File.fromUri(Uri.parse(path)).delete();
    await AlbumManager.getAlbums();
  }
}

class AlbumManager {
  static Future<Directory> directory = (() async {
    var directory =
        Directory('${(await getApplicationDocumentsDirectory()).path}/emu');
    await directory.create();
    await Directory(
            '${(await getApplicationDocumentsDirectory()).path}/emu/songs')
        .create();
    return directory;
  }());

  static List<Album> albums = [];

  static Future<void> _download(Uri url, String? fname) async {
    final request = await HttpClient().getUrl(url);
    final response = await request.close();
    var path = (await directory).path;

    if (fname == null) {
      var text = await http.read(url);
      var album = Album.fromText(text, '');
      File('$path/${album.name}.yaml').writeAsString(text);
    } else {
      response.pipe(File('$path/$fname').openWrite());
    }
  }

  static Future<void> addAlbum(String url) async {
    await _download(Uri.parse(url), null);
  }

  static Future<void> getAlbums() async {
    var files = await (await directory).list().toList();
    List<Album> a = [];
    for (var f in files.whereType<File>()) {
      a.add(Album.fromText(await f.readAsString(), f.path));
    }
    albums = a;
  }
}

class PlaybackManager {
  static List<Song> queue = [];
  static int? current;

  static Player player = Player();

  static void init() {
    player.stream.playing.listen((playing) {
      _audioHandler.update();
    });
    player.stream.completed.listen((event) {
      if (event == true && hasNext()) {
        playNext();
      }
    });
  }

  static Song? currentSong() {
    if (current != null) {
      return queue.elementAtOrNull(current!);
    } else {
      return null;
    }
  }

  static void updateQueue(List<Song> newQueue) {
    _audioHandler.queue
        .add([...newQueue].map((song) => song.toMediaItem()).toList());
    queue = newQueue;
  }

  static void playSong(Song song) {
    updateQueue([song]);
    current = 0;
    play();
  }

  static void playAlbum(Album album) {
    updateQueue([...album.getSongs()]);
    current = 0;
    play();
  }

  static void playAlbumShuffled(Album album) {
    updateQueue([...album.getSongs()]);
    queue.shuffle();
    current = 0;
    play();
  }

  static void clear() {
    queue = [];
  }

  static Future<void> seek(double position) async {
    await player.seek(Duration(
        milliseconds:
            (position * player.state.duration.inMilliseconds.toDouble())
                .round()));
  }

  static Future<void> stop() async {
    await player.stop();
  }

  static Future<void> play() async {
    _audioHandler.update();
    await player.open(Media(queue[current!].url.toString()));
  }

  static Future<void> playNext() async {
    current = current! + 1;
    await play();
  }

  static Future<void> playPrevious() async {
    current = current! - 1;
    await play();
  }

  static bool isPlaying() {
    return player.state.playing;
  }

  static Future<void> resume() async {
    await player.play();
  }

  static Future<void> pause() async {
    await player.pause();
  }

  static bool hasNext() {
    return current! + 1 < queue.length;
  }

  static bool hasPrevious() {
    return current! > 0;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Emu'),
    );
  }
}

class _AlbumScreen extends StatelessWidget {
  final int albumId;
  const _AlbumScreen(this.albumId);

  @override
  Widget build(BuildContext context) {
    var songs = AlbumManager.albums[albumId].getSongs();

    List<Widget> listTiles = [
      TextButton(
          onPressed: () {
            PlaybackManager.playAlbum(AlbumManager.albums[albumId]);
          },
          child: const Text('Play Album')),
      TextButton(
          onPressed: () {
            PlaybackManager.playAlbumShuffled(AlbumManager.albums[albumId]);
          },
          child: const Text('Shuffle Play')),
      TextButton(
          onPressed: () async {
            showDialog<void>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Confirm Delete Album'),
                  content: const SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        Text('Are you sure you want to delete this album?'),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    TextButton(
                      child: const Text('Delete'),
                      onPressed: () async {
                        await AlbumManager.albums[albumId].delete();
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                        Navigator.of(context).setState(() {});
                      },
                    ),
                  ],
                );
              },
            );
          },
          child: const Text('Delete')),
      TextButton(
          onPressed: () {
            PlaybackManager.playAlbumShuffled(AlbumManager.albums[albumId]);
          },
          child: const Text('Shuffle Play')),
    ];

    for (var song in songs) {
      listTiles.add(ListTile(
        title: Text(song.name),
        onTap: () {
          PlaybackManager.playSong(song);
        },
      ));
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
        bottomNavigationBar: _SongBar());
  }
}

class _AlbumPageState extends State<_AlbumPage> {
  Future<void> updateAlbums() async {
    await AlbumManager.getAlbums();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    updateAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
          itemCount: AlbumManager.albums.length,
          itemBuilder: (context, index) {
            return Card(
                child: ListTile(
              title: Text(AlbumManager.albums[index].name),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => _AlbumScreen(index)),
                );
              },
            ));
          }),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          _displayTextInputDialog(context, 'Add Album from URL', (text) async {
            try {
              await AlbumManager.addAlbum(text);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Album Added')));
              await updateAlbums();
            } catch (e) {
              print(e);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Error')));
            }
          });
        },
      ),
    );
  }
}

class _AlbumPage extends StatefulWidget {
  const _AlbumPage(this.scaffoldKey);
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  State<StatefulWidget> createState() => _AlbumPageState();
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static const List<String> drawerNames = ['Albums', 'Other'];

  late final AppLifecycleListener _listener;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _listener.dispose();
    PlaybackManager.player.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _listener = AppLifecycleListener(
      onExitRequested: () async {
        await PlaybackManager.stop();
        return AppExitResponse.exit;
      },
    );

    super.initState();

    PlaybackManager.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(drawerNames[_selectedIndex])),
        drawer: Drawer(
            child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(widget.title),
            ),
            ListTile(
              title: const Text('Albums'),
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Other'),
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
          ],
        )),
        body: _selectedIndex == 0 ? _AlbumPage(_scaffoldKey) : const Text('No'),
        bottomNavigationBar: _SongBar());
  }
}

class _SongBar extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SongBarState();
}

class _SongBarState extends State<_SongBar> {
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
    if (PlaybackManager.queue.isEmpty) {
      return const SizedBox.shrink();
    } else {
      IconData icon;
      if (PlaybackManager.isPlaying()) {
        icon = Icons.pause;
      } else {
        icon = Icons.play_arrow;
      }
      return Card(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
      ]));
    }
  }
}
