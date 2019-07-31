import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';

import 'package:version/version.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'model/Participant.dart';
import 'model/Event.dart';
import 'model/Task.dart';
import 'model/Submission.dart';

const BASE_URL = "https://ranky.olinfo.it/";
// const BASE_URL = "http://192.168.1.102:5000/";

Future<List<Event>> fake_getEvents() async {
  List<Event> events = [];
  for (int i=0; i<15; i++) {
    events.add(Event(
        id: "test${i}",
        name: "Test ${i} — The Contest",
        description: "Test Contest 123${i}9",
        distance: 123456.789 * i,
        logo: Image.asset("images/ranking.png", width: 50)
    ));
  }
  return Future.delayed(Duration(seconds: 2), () => events);
}

Future<List<Participant>> fake_getParticipants() async {
  List<Participant> ranking = [];
  for (int i=0; i<15; i++) {
    ranking.add(Participant(
      id: "user${i}",
      firstName: "Test ${i}",
      lastName: "Johnson",
      score: i * 3.7,
      face: AssetImage("images/ranking.png")
    ));
  }
  return Future.delayed(Duration(seconds: 2), () => ranking);
}

Future<List<Event>> getEvents() async {
  var response = await http.get(BASE_URL, headers: {'Accept': 'application/json'});
  var location;
  try {
    location = await Location().getLocation();
  } on PlatformException catch (e) {
    if (e.code == 'PERMISSION_DENIED') {
      // report this somewhere?
    }
    location = null;
  }

  List<Event> events = [];
  for (var e in jsonDecode(response.body)) {
    var event = Event(
        id: e["id"],
        name: e["name"],
        description: e["description"],
        latitude: e["latitude"],
        longitude: e["longitude"],
        url: e["url"],
        status: e["status"],
        hidden: e["hidden"],
        totalTasks: e["totalTasks"],
        logo: Image.network(BASE_URL + "static/" + e["id"] + ".png", width: 50)
    );

    if (event.hidden) {
      continue;
    }

    if (e["teamNamespace"] != null) {
      event.teamNamespace = e["teamNamespace"];
    }

    if (location != null) {
      event.distance = GreatCircleDistance(
          latitude1: location.latitude,
          longitude1: location.longitude,
          latitude2: event.latitude,
          longitude2: event.longitude
      ).distance();
    }

    event.startTimes = List<int>();
    for (var t in e["startTimes"]) {
      event.startTimes.add(t);
    }
    event.startTimes.sort();

    // Test if it's online
//    try {
//      var test = await http.get(event.url + '/contests/', headers: {'Accept': 'application/json'});
//      jsonDecode(test.body);
//      event.status = "live";
//    } catch (e) {
//      event.status = "offline";
//    }

    events.add(event);
  }

  if (location != null) {
    // Sort by ascending distance and then name
    events.sort((Event a, Event b) {
      if (a.distance > b.distance) {
        return 1;
      } else if (b.distance > a.distance) {
        return -1;
      } else {
        return a.name.compareTo(b.name);
      }
    });
  } else {
    // Sort by name
    events.sort((Event a, Event b) => a.name.compareTo(b.name));
  }

  return events;
}

Future<void> fillEventInfo(String url, Event event) async {
  var tasks = await getTasks(url);
  event.teams = await getTeams(url);

  event.visibleTasks = tasks.length;

  event.maxScore = 0;
  for (var t in tasks) {
    event.maxScore += t.maxScore;
  }
}

Future<List<Participant>> getParticipants(Event event) async {
  var usersResponse = await http.get(event.url + "/users/", headers: {'Accept': 'application/json'});
  var scoresResponse = await http.get(event.url + "/scores", headers: {'Accept': 'application/json'});
  List<Participant> participants = [];

  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> list = prefs.getStringList("ranky.favorites") ?? [];

  Map<String, double> score = Map<String, double>();
  jsonDecode(scoresResponse.body).forEach((key, value) {
    value.forEach((task, subScore) {
      score.putIfAbsent(key, () => 0);
      score[key] += subScore;
    });
  });

  jsonDecode(usersResponse.body).forEach((key, e) => participants.add(Participant(
      id: key,
      firstName: e["f_name"],
      lastName: e["l_name"],
      team: e["team"],
      isFavorite: list.contains(key + "~" + event.id),
      score: score[key] ?? 0,
      face: NetworkImage(event.url + "/faces/" + key, headers: {'Accept': '*/*'}),
      iface: Image.network(event.url + "/faces/" + key, headers: {'Accept': '*/*'}, fit: BoxFit.cover)
  )));

  participants.sort((Participant a, Participant b) {
    return b.score.compareTo(a.score);
  });

  participants[0].rank = 1;
  for (int i = 1; i < participants.length; i++) {
    participants[i].rank = participants[i - 1].rank;
    if (participants[i].score < participants[i - 1].score) {
      participants[i].rank += 1;
    }
  }

  return participants;
}

Future<List<Task>> getTasks(String url) async {
  var response = await http.get(url + "/tasks/", headers: {'Accept': 'application/json'});

  List<Task> tasks = [];
  jsonDecode(response.body).forEach((key, e) {
    var task = Task(
      id: key,
      name: e["name"],
      shortName: e["short_name"],
      contest: e["contest"],
      order: e["order"],
      maxScore: e["max_score"],
      scorePrecision: e["score_precision"],
      numSubtasks: (e["extra_headers"] != null) ? e["extra_headers"].length : 1
    );

    tasks.add(task);
  });

  // Sort by ascending 'contest' and then 'order'
  tasks.sort((Task a, Task b) {
    if (a.contest != b.contest) {
      return a.contest.compareTo(b.contest);
    } else {
      return a.order.compareTo(b.order);
    }
  });

  return tasks;
}

Future<Map<String, String>> getTeams(String url) async {
  var response = await http.get(url + "/teams/", headers: {'Accept': 'application/json'});

  Map<String, String> teams = Map<String, String>();
  jsonDecode(response.body).forEach((key, e) {
    teams[key] = e["name"];
  });

  return teams;
}

Future<List<Submission>> getSubmissions(Event event, String userId) async {
  var response = await http.get(event.url + "/sublist/" + userId, headers: {'Accept': 'application/json'});

  List<Submission> subs = [];

  for (var e in jsonDecode(response.body)) {
    var sub = Submission(
      id: e["key"],
      task: e["task"],
      time: e["time"]
    );

    sub.subScore = List<double>();
    if (e["extra"] == null) {
      sub.subScore.add(e["score"]);
    } else {
      for (var i = 0; i < e["extra"].length; i++) {
        sub.subScore.add(double.parse(e["extra"][i]));
      }
    }

    subs.add(sub);
  }

  subs.sort((Submission a, Submission b) {
    return b.time.compareTo(a.time);
  });

  int startIndex = event.startTimes.length - 1;
  for (var i = 0; i < subs.length; i++) {
    if (subs[i].time < event.startTimes[startIndex]) {
      if (startIndex > 0) {
        startIndex -= 1;
      } else {
        // this should never happen!
      }
    }

    subs[i].relTime = subs[i].time - event.startTimes[startIndex];
    subs[i].day = startIndex + 1;
  }

  var tasks = await getTasks(event.url);

  Map<String, List<double>> best = Map<String, List<double>>();
  for (var t in tasks) {
    best[t.id] = List<double>();
    for (var i = 0; i < t.numSubtasks; i++) {
      best[t.id].add(0);
    }
  }

  for (var i = subs.length - 1; i >= 0; i--) {
    subs[i].delta = 0;
    for (var j = 0; j < best[subs[i].task].length; j++) {
      if (best[subs[i].task][j] < subs[i].subScore[j]) {
        subs[i].delta += subs[i].subScore[j] - best[subs[i].task][j];
        best[subs[i].task][j] = subs[i].subScore[j];
      } else {
        subs[i].subScore[j] = best[subs[i].task][j];
      }
    }
  }

  return subs;
}

Future<bool> checkAppTooOld() async {
  try {
    var response = await http.get(BASE_URL + '/min-app-version');
    var obj = jsonDecode(response.body);

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Version currentVersion = Version.parse(packageInfo.version);

    if (Version.parse(obj["min_version"]) > currentVersion) {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}

class GreatCircleDistance {
  final double R = 6371000;  // radius of Earth, in meters
  double latitude1, longitude1;
  double latitude2, longitude2;

  GreatCircleDistance({this.latitude1, this.latitude2, this.longitude1, this.longitude2});

  double distance() {
    double phi1 = this.latitude1 * pi / 180;  // φ1
    double phi2 = this.latitude2 * pi / 180;  // φ2
    var deltaPhi = (this.latitude2 - this.latitude1) * pi / 180;  // Δφ
    var deltaLambda = (this.longitude2 - this.longitude1) * pi / 180;  // Δλ

    var a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
            cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }
}