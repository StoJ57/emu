import 'package:flutter/material.dart';
import 'dart:async';

import 'audio.dart';
import 'album.dart';

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

class LibraryState extends State<Library> {
  Timer? timer;

  @override
  void dispose() {
    timer!.cancel();
    super.dispose();
  }

  @override
  void initState() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
          itemCount: AlbumManager.library.length,
          itemBuilder: (context, index) {
            return Card(
                child: ListTile(
              title: Text(AlbumManager.library[index].name),
              subtitle: Text(AlbumManager.library[index].getSubtitle()),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AlbumPage(
                              AlbumManager.albums
                                  .indexOf(AlbumManager.library[index]), () {
                            setState(() {});
                          })),
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
              await AlbumManager.updateFromFS();
            } catch (e) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Error')));
            }
          });
        },
      ),
    );
  }
}

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  State<StatefulWidget> createState() => LibraryState();
}
