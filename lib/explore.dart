import 'package:flutter/material.dart';
import 'dart:async';

import 'audio.dart';
import 'album.dart';

class ExplorePageState extends State<ExplorePage> {
  Timer? timer;

  List<String> search = [];

  @override
  Widget build(BuildContext context) {
    List<Widget> results = [];
    var i = 0;
    for (var album in AlbumManager.albums) {
      bool matches = search.isEmpty && album.browseable;

      if (!matches) {
        for (String term in search) {
          if (album.matchesSearch(term)) {
            matches = true;
            break;
          }
        }
      }

      if (matches) {
        int navigateIndex = i; // copy value

        results.add(ListTile(
          title: Text(album.name),
          subtitle: Text(album.getSubtitle()),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                return AlbumPage(navigateIndex, () {
                  setState(() {});
                });
              }),
            );
          },
        ));
      }
      i += 1;
    }

    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SearchBar(
              leading: const Icon(Icons.search),
              onChanged: (value) {
                setState(() {
                  if (value.isEmpty) {
                    search = [];
                  } else {
                    search = value
                        .split(' ')
                        .where((element) => element.isNotEmpty)
                        .toList();
                  }
                });
              },
            ),
            Expanded(
                child: ListView(
                    children:
                        ListTile.divideTiles(tiles: results, context: context)
                            .toList()))
          ],
        ));
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<StatefulWidget> createState() => ExplorePageState();
}
