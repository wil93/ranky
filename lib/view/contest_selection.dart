import 'dart:math';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

import '../model/Event.dart';
import '../data.dart';
import 'ranking_view.dart';

class ContestSelection extends StatefulWidget {
  ContestSelection({Key key}) : super(key: key);

  @override
  _ContestSelectionState createState() => new _ContestSelectionState();
}

class _ContestSelectionState extends State<ContestSelection> {
  final TextEditingController _searchField = new TextEditingController();
  bool _appTooOld = false;
  bool _searchOpen = false;
  bool _mapView = false;
  List<Event> _events;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  _ContestSelectionState() {
    _searchField.addListener(() {
      print(_searchField.text);
    });
  }

  @override
  void initState() {
//    SchedulerBinding.instance.addPostFrameCallback((_){  _refreshIndicatorKey.currentState?.show(); } );
    _refreshContestList();

    // Maybe move this in some higher level widget that contains everything
    FirebaseMessaging().requestNotificationPermissions();
    FirebaseMessaging().configure(onMessage: (s) async {
      print("Received notification!");
      print(s);

      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          // If the notification title contains "...increased..." then it's a "yay" notification
          bool yay = s["notification"]["title"].toString().indexOf("increased") != -1;

          return AlertDialog(
            title: new Text(s["notification"]["title"]),
            content: new Text(s["notification"]["body"]),
            actions: <Widget>[
              // usually buttons at the bottom of the dialog
              new FlatButton(
                child: new Text(yay ? "Yay!" : "OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }, onResume: (s) async {
      print("Resumed from notification!");
      print(s);
    });
  }

  Future<void> _refreshContestList() async {
//    var events = await fake_getEvents();
    var appTooOld = await checkAppTooOld();
    if (appTooOld) {
      setState(() {
        _appTooOld = true;
      });
      return;
    }

    var events = await getEvents();

//    _refreshIndicatorKey.currentState?.deactivate();
    if (!mounted) return;

    setState(() {
      _events = events;
    });
  }

  Widget _getPlatformStoreIcon() {
    if (Platform.isIOS) {
      return GestureDetector(
        child: Image.asset("images/appstore.png"),
        onTap: () {
          _launchURL("https://play.google.com/store/apps/details?id=org.ioinformatics.ranky");
        }
      );
    } else {
      return GestureDetector(
        child: Image.asset("images/playstore.png"),
        onTap: () {
          _launchURL("https://play.google.com/store/apps/details?id=org.ioinformatics.ranky"); // TODO: fix url
        }
      );
    }

    // Other options:
    // Platform.isAndroid
    // Platform.isFuchsia
    // Platform.isLinux
    // Platform.isMacOS
    // Platform.isWindows
  }

  _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_appTooOld) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Unsupported version')
        ),
        body: Container(
          padding: EdgeInsets.all(10),
          child: Column(
            children: <Widget>[
              Text("Sorry, this version of Ranky is not supported anymore.\n\nPlease update to the latest version:\n", style: TextStyle(fontSize: 24)),
              _getPlatformStoreIcon()
            ],
          )
        )
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Choose a contest'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (s) {
              if (s == 'sort_dist') {
                setState(() {
                  _mapView = false;
                  _events.sort((Event a, Event b) => a.distance.compareTo(b.distance));
                });
              } else if (s == 'sort_name') {
                setState(() {
                  _mapView = false;
                  _events.sort((Event a, Event b) => a.name.compareTo(b.name));
                });
              } else if (s == 'show_map') {
                setState(() {
                  _mapView = true;
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
              const PopupMenuItem<String>(
                value: 'sort_dist',
                child: Text('List by distance'),
              ),
              const PopupMenuItem<String>(
                value: 'sort_name',
                child: Text('List by name'),
              ),
              const PopupMenuItem<String>(
                value: 'show_map',
                child: Text('Show on the map')
              ),
            ],
          ),

        ],
      ),
      body: _mapView ? _buildContestMap(context) : _buildContestList(context),
//      floatingActionButton: _mapView ? null : FloatingActionButton(
//        onPressed: () {
//          setState(() {
//            _mapView = true;
//          });
//        },
//        child: Icon(Icons.search),
//        backgroundColor: Colors.blue,
//      )
    );
  }

  Widget _buildContestList(BuildContext context) {
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _refreshContestList,
      child: ListView.builder(
        padding: EdgeInsets.only(top: 2),
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: _events[index].logo,
            trailing: Icon(Icons.fiber_manual_record, color: _events[index].status == "live" ? Colors.green : Colors.red),
            title: Text(_events[index].name),
            subtitle: _events[index].distance != null ? Text('Distance: ' + (_events[index].distance / 1000).toStringAsFixed(2) + ' km') : Text('Distance: unknown'),
            onTap: () {
              if (_events[index].status == "live") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Ranking(event: _events[index])),
                );
              } else {
                Scaffold.of(context).hideCurrentSnackBar();
                Scaffold.of(context).showSnackBar(SnackBar(content: Text('The selected contest seems to be offline!')));
              }
            },
          )
        ),
        itemCount: _events == null ? 0 : _events.length
      )
    );
  }

  Widget _buildContestMap(BuildContext context) {
    Set<Marker> set = Set<Marker>();
    for (var e in _events) {
      set.add(
        Marker(
          markerId: MarkerId(e.id),
          position: LatLng(e.latitude, e.longitude),
          infoWindow: InfoWindow(
            title: e.name,
            onTap: () {
              if (e.status == "live") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => Ranking(event: e)),
                );
              } else {
                showDialog(context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: new Text("Offline"),
                      content: new Text('The selected contest seems to be offline!'),
                      actions: <Widget>[
                        new FlatButton(
                          child: new Text("OK"),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              }
            }
          )
        )
      );
    }

    return GoogleMap(
      markers: set,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      mapType: MapType.normal,
      initialCameraPosition: CameraPosition(
        target: LatLng(0, 0),
        zoom: 0,
      )
    );
  }

  Widget _buildBar(BuildContext context) {
    return new SliverAppBar(
      floating: true,
      snap: true,
      title: Text("Search App"),
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () {
            showSearch(
              context: context,
              delegate: ContestSearchDelegate(),
            );
          },
        ),
      ],
    );
  }
}