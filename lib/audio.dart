import 'package:audio_service/audio_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_session/audio_session.dart';

class AlbumManager {
  static Future<String> directory = (() async {
    var directory =
        Directory('${(await getApplicationDocumentsDirectory()).path}/emu');
    await directory.create();
    await Directory(
            '${(await getApplicationDocumentsDirectory()).path}/emu/remote')
        .create();
    return directory.path;
  }());

  static List<Album> library = [];

  static List<Album> albums = [];

  static Future<void> _download(Uri url, String? fname) async {
    final request = await HttpClient().getUrl(url);
    final response = await request.close();
    var path = '${await directory}/remote';

    if (fname == null) {
      var text = await http.read(url);
      var fname = Uri.encodeComponent(url.toString());
      File('$path/$fname').writeAsString(text);
    } else {
      response.pipe(File('$path/$fname').openWrite());
    }
  }

  static Future<void> addAlbum(String url) async {
    await _download(Uri.parse(url), null);
  }

  static Future<int> updateFromFS() async {
    var files = await Directory('${await directory}/remote').list().toList();
    List<Album> a = [];

    int errs = 0;

    for (var f in files.whereType<File>()) {
      try {
        a.add(Album.fromText(await f.readAsString(), f.path));
      } catch (e) {
        print("Could not parse album: " + Uri.decodeComponent(f.path));
        print(e);
        errs += 1;
      }
    }
    albums = a;
    await readLibrary();

    return errs;
  }

  static Future<void> readLibrary() async {
    var file = File('${await directory}/library.txt');
    library = [];
    if (!await file.exists()) {
      await writeLibrary();
    } else {
      for (var line in await file.readAsLines()) {
        for (var a in albums) {
          if (a.path == line) {
            library.add(a);
          }
        }
      }
    }
  }

  static Future<void> writeLibrary() async {
    String text = '';
    for (var album in library) {
      text += '${album.path}\n';
    }
    var file = File('${await directory}/library.txt');
    await file.writeAsString(text);
  }

  static Future<int> downloadAll() async {
    var response = await http.get(Uri.parse(
        'https://raw.githubusercontent.com/StoJ57/emu-albums/main/registry.txt'));
    String registry = response.body;

    List<String> albums = [];

    for (String a in registry.split('\n')) {
      if (a != "") {
        albums.add(a);
      }
    }

    var files = await Directory('${await directory}/remote').list().toList();
    for (var f in files.whereType<File>()) {
      var name = f.uri.pathSegments.last;
      if (!albums.contains(Uri.decodeComponent(name))) {
        await f.delete();
      }
    }

    for (var album in albums) {
      await _download(Uri.parse(album), null);
    }
    return await AlbumManager.updateFromFS();
  }
}

class Song {
  Uri url;
  Uri? artUrl;
  String name;

  String? artist;
  String? performer;
  String? licence;

  Song(this.name, this.url, this.artUrl, this.artist, this.performer,
      this.licence);

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

  Media getMedia() {
    return Media(url.toString());
  }

  String getArtist() {
    if (artist != null) {
      if (performer != null && performer != artist) {
        return '$artist - performed by $performer';
      } else {
        return artist!;
      }
    } else {
      return '';
    }
  }

  String getSubtitle() {
    if (licence != null) {
      return '${getArtist()} (licensed under $licence)';
    } else {
      return getArtist();
    }
  }

  bool matchesSearch(String search) {
    if (artist != null &&
        artist!.toUpperCase().contains(search.toUpperCase())) {
      return true;
    } else if (performer != null &&
        performer!.toUpperCase().contains(search.toUpperCase())) {
      return true;
    } else {
      return name.toUpperCase().contains(search.toUpperCase());
    }
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: url.toString(),
      title: name.toString(),
      artUri: artUrl,
      artist: getArtist(),
    );
  }
}

class Album {
  String name;
  String path;
  List<Song> include;
  List<Song> exclude;

  String? artist;
  String? performer;
  String? licence;

  Album(this.name, this.include, this.exclude, this.path);

  static Album fromText(String text, String path) {
    var doc = loadYaml(text);
    List<Song> include = [];
    List<Song> exclude = [];
    Uri? art;

    String? artist;
    if (doc['artist'] != null) {
      artist = doc['artist']!;
    }
    String? performer;
    if (doc['performer'] != null) {
      performer = doc['performer']!;
    }
    String? licence;
    if (doc['licence'] != null) {
      licence = doc['licence']!;
    }

    if (doc['art'] != null) {
      art = Uri.parse(doc['art']!);
    }

    if (doc['include'] != null) {
      for (var n in doc['include']) {
        if (n is! YamlMap) {
          throw 'Invalid YAML';
        }
        for (var s in n.entries) {
          include.add(
              Song(s.key, Uri.parse(s.value), art, artist, performer, licence));
        }
      }
    }
    if (doc['exclude'] != null) {
      // TODO
    }

    var album = Album(doc['name'], include, exclude, path);
    album.artist = artist;
    album.performer = performer;
    album.licence = licence;

    return album;
  }

  String getArtist() {
    if (artist != null) {
      if (performer != null && performer != artist) {
        return '$artist - performed by $performer';
      } else {
        return artist!;
      }
    } else {
      return '';
    }
  }

  String getSubtitle() {
    if (licence != null) {
      return '${getArtist()} (licensed under $licence)';
    } else {
      return getArtist();
    }
  }

  bool matchesSearch(String search) {
    for (Song song in getSongs()) {
      if (song.matchesSearch(search)) {
        return true;
      }
    }
    return name.toUpperCase().contains(search.toUpperCase());
  }

  List<Song> getSongs() {
    return include;
  }
}

class AudioPlayerHandler extends BaseAudioHandler {
  void update(Duration? position) {
    if (PlaybackManager.currentSong() != null) {
      mediaItem.add(PlaybackManager.currentSong()!
          .toMediaItem()
          .copyWith(duration: PlaybackManager.player.state.duration));
      List<MediaControl> controls = [MediaControl.skipToPrevious];
      if (PlaybackManager.isPlaying()) {
        controls.add(MediaControl.pause);
      } else {
        controls.add(MediaControl.play);
      }
      if (PlaybackManager.hasNext()) {
        controls.add(MediaControl.skipToNext);
      }
      if (position == null) {
        playbackState.value = PlaybackState(
          controls: controls,
          playing: PlaybackManager.isPlaying(),
          processingState: AudioProcessingState.ready,
        );
      } else {
        playbackState.value = PlaybackState(
          controls: controls,
          playing: PlaybackManager.isPlaying(),
          processingState: AudioProcessingState.ready,
          updatePosition: position,
          updateTime: DateTime.now(),
        );
      }
    } else {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
      ));
    }
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

late AudioPlayerHandler audioHandler;

class PlaybackManager {
  static List<Song> queue = [];
  static int? current;

  static Player player = Player();
  static late AudioSession session;

  static bool nextLoaded = false;

  static void init() async {
    player.stream.duration.listen((duration) {
      audioHandler.update(player.state.position);
    });
    player.stream.playing.listen((playing) {
      audioHandler.update(player.state.position);
    });
    player.stream.completed.listen((event) {
      if (event == true && hasNext()) {
        playNext();
      }
    });
    session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.becomingNoisyEventStream.listen((_) async {
      await pause();
    });
    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            await player.setVolume(40);
          case AudioInterruptionType.pause:
            await pause();
          case AudioInterruptionType.unknown:
            await pause();
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            await player.setVolume(100);
          case AudioInterruptionType.pause:
            await resume();
          case AudioInterruptionType
                .unknown: // The interruption ended but we should not resume.
        }
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
    audioHandler.queue
        .add([...newQueue].map((song) => song.toMediaItem()).toList());
    queue = newQueue;
    if (nextLoaded) {
      player.remove(1);
      nextLoaded = false;
    }
  }

  static void playSong(Song song) {
    updateQueue([song]);
    current = 0;
    play();
  }

  static void playAlbum(Album album, int startIndex) {
    updateQueue([...album.getSongs()]);
    current = startIndex;
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
    Duration positionDur = Duration(
        milliseconds:
            (position * player.state.duration.inMilliseconds.toDouble())
                .round());
    await player.seek(positionDur);
    audioHandler.update(positionDur);
  }

  static Future<void> stop() async {
    await player.stop();
    await session.setActive(false);
  }

  static Future<void> play() async {
    if (await session.setActive(true,
        androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media))) {
    } else {
      print("Could not set audio active");
    }

    if (nextLoaded) {
      nextLoaded = false;
    } else {
      await player.open(Playlist([queue[current!].getMedia()]));
    }

    if (queue.length > current! + 1) {
      await player.add(queue[current! + 1].getMedia());
      nextLoaded = true;
    } else {
      nextLoaded = false;
    }
  }

  static Future<void> playNext() async {
    current = current! + 1;
    nextLoaded = false;
    await play();
  }

  static Future<void> playPrevious() async {
    current = current! - 1;
    nextLoaded = false;
    await play();
  }

  static bool isPlaying() {
    return player.state.playing;
  }

  static Future<void> resume() async {
    if (await session.setActive(true)) {
      await player.play();
    } else {
      print("Could not set audio active");
    }
  }

  static Future<void> pause() async {
    await player.pause();
    await session.setActive(false);
  }

  static bool hasNext() {
    return current! + 1 < queue.length;
  }

  static bool hasPrevious() {
    return current! > 0;
  }
}
