import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Participant {
  Participant({
    this.id,
    this.firstName,
    this.lastName,
    this.team,
    this.score,
    this.isFavorite,
    this.face,
    this.iface,
    this.rank,
  });

  String id;
  String firstName;
  String lastName;
  String team;
  double score;
  ImageProvider face;
  Image iface;
  int rank;

  bool isFavorite;

  void toggleFavorite(BuildContext context, String key) async {
    FirebaseMessaging firebaseMessaging = new FirebaseMessaging();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList("ranky.favorites") ?? [];

    if (this.isFavorite) {
      this.isFavorite = false;

      // Remove it from SharedPreferences
      list.remove(key);

      // Unsubscribe from GCM topic
      firebaseMessaging.unsubscribeFromTopic(key);

      // Show message
      Scaffold.of(context).hideCurrentSnackBar();
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('You will stop receiving live updates for this contestant.')));
    } else {
      this.isFavorite = true;

      // Add it to SharedPreferences
      list.add(key);

      // Subscribe to GCM topic
      firebaseMessaging.subscribeToTopic(key);

      // Show message
      Scaffold.of(context).hideCurrentSnackBar();
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('From now you will be notified of the activity of this contestant.')));
    }

    prefs.setStringList("ranky.favorites", list);
  }

  String title() {
    return this.firstName + ' ' + this.lastName;
  }

  Text rankText() {
    double fontSize = 12;

    if (rank < 10) {
      fontSize = 18;
    } else if (rank < 100) {
      fontSize = 16;
    } else if (rank < 1000) {
      fontSize = 14;
    }

    return Text(this.rank.toString(), style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold));
  }
}
