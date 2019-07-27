import 'package:flutter/material.dart';
import 'view/contest_selection.dart';
import 'package:flutter/services.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

class RankyApp extends StatelessWidget {
  static const String _title = 'Ranky';
  DateTime currentBackPressTime;

  final FirebaseAnalytics analytics = FirebaseAnalytics();

  RankyApp() {

  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        child: MaterialApp(
          title: _title,
          home: ContestSelection(),
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: analytics),
          ],
        ),
        onWillPop: () {
          return showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Confirm Exit"),
                  content: Text("Are you sure you want to exit?"),
                  actions: <Widget>[
                    FlatButton(
                      child: Text("YES"),
                      onPressed: () {
                        SystemNavigator.pop();
                      },
                    ),
                    FlatButton(
                      child: Text("NO"),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  ],
                );
              });
        });
  }
}

void main() {
  runApp(RankyApp());
}
