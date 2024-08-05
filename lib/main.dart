import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';

import 'audio.dart';
import 'explore.dart';
import 'library.dart';
import 'song.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AlbumManager.updateFromFS();
  audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.emu.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'mipmap/ic_launcher'),
  );
  AppLifecycleListener(onExitRequested: () async {
    await PlaybackManager.stop();
    PlaybackManager.player.dispose();
    DownloadManager.dispose(); // Safe download cancellation for app shutdown
    return AppExitResponse.exit;
  }, onPause: () {
    PlaybackManager.background = true;
  }, onResume: () {
    PlaybackManager.background = false;
  });
  runApp(const MyApp());
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static const List<String> drawerNames = ['Library', 'Explore'];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    AlbumManager.downloadAll().then((errs) => {
          if (errs > 1)
            {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Errors importing $errs albums')))
            }
          else if (errs == 1)
            {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error importing 1 album')))
            }
        });

    super.initState();
    PlaybackManager.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              title: const Text('Library'),
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Explore'),
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
          ],
        )),
        body: _selectedIndex == 0 ? const Library() : const ExplorePage(),
        bottomNavigationBar: const SongBar());
  }
}
