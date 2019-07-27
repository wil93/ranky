import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data.dart';

class Event {
  Event({
    this.id,
    this.name,
    this.description,
    this.url,
    this.teamNamespace,
    this.status,
    this.hidden,
    this.latitude,
    this.longitude,
    this.distance,
    this.startTimes,
    this.logo,
    this.maxScore,
    this.totalTasks,
    this.visibleTasks
  });

  String id;
  String name;
  String description;
  String url;
  String teamNamespace;
  String status;
  bool hidden;
  double latitude;
  double longitude;
  double distance;
  List<int> startTimes;
  Widget logo;
  double maxScore;
  int totalTasks;
  int visibleTasks;
  Map<String, String> teams;

  Image getFlag(String teamCode) {
    String url = BASE_URL + 'static/flags/countries/' + teamCode + '.png';

    if (this.teamNamespace != null) {
      url = BASE_URL + 'static/flags/' + this.teamNamespace + '/' + teamCode +
          '.png';
    }

    return Image.network(url, fit: BoxFit.contain);
  }
}