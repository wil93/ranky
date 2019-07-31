import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../model/Event.dart';
import '../model/Participant.dart';
import '../model/Submission.dart';
import '../data.dart';

class ParticipantView extends StatefulWidget {
  final Event event;
  final Participant participant;
  const ParticipantView({Key key, this.event, this.participant}) : super(key: key);

  @override
  _ParticipantState createState() => new _ParticipantState();
}

class _ParticipantState extends State<ParticipantView> {
  List<Submission> _subs;
  List<MapEntry<String, double>> _taskscore;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  _ParticipantState() {

  }

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((_){  _refreshIndicatorKey.currentState?.show(); } );
    _refreshParticipant();
  }

  Future<void> _refreshParticipant() async {
//    var ranking = await fake_getParticipants();
    var subs = await getSubmissions(widget.event, widget.participant.id);
    var tasks = await getTasks(widget.event.url);

    Map<String, double> best = Map<String, double>();
    for (var t in tasks) {
      best[t.id] = 0;
    }
    for (var s in subs) {
      best[s.task] = max(best[s.task], s.score());
    }

    List<MapEntry<String, double>> taskscore = [];
    for (var t in tasks) {
      taskscore.add(MapEntry(t.shortName, best[t.id]));
    }

    _refreshIndicatorKey.currentState?.deactivate();
    if (!mounted) return;

    setState(() {
      _subs = subs;
      _taskscore = taskscore;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshParticipant,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              floating: true,
              flexibleSpace: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  var height = constraints.biggest.height;

                  // h = 80 ~~~ 224
                  // s = 72 ~~~ 10
                  var start = (height - 80) / (224 - 80);
                  start = 72 + start * (10 - 72);

                  return InkWell(
                    splashColor: Colors.transparent,
                    onTap: () {
                      if (height < 100) {
                        // Ignore this tap, because probably the user doesn't want to
                        // zoom the picture (maybe they just missed the back button)
                      } else {
                        // The user clicked on the picture so they want to zoom it
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Scaffold(
                            body: DecoratedBox(
                              child: Container(),
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: widget.participant.face,
                                  fit: BoxFit.cover
                                )
                              ),
                            ),
                          )),
                        );
                      }
                    },
                    child: FlexibleSpaceBar(
                      titlePadding: EdgeInsetsDirectional.only(start: start, bottom: 16),
                      title: Container(
                        height: 25,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            widget.event.getFlag(widget.participant.team),
                            Container(width: 10),
                            Expanded(child: Text(
                              widget.participant.title(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis
                            ))
                          ],
                        )
                      ),
                      background: Stack(
                        children: <Widget>[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: widget.participant.face,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              gradient: LinearGradient(
                                begin: FractionalOffset.topCenter,
                                end: FractionalOffset.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.6),
                                ],
                                stops: [
                                  0.0,
                                  1.0
                                ]
                              )
                            ),
                          )
                        ]
                      ),
                    )
                  );
                }
              )
            ),
            SliverList(delegate:
              SliverChildListDelegate(<Widget>[
                _buildScoreChart(context),
                Divider(),
                _buildSubmissionList(context)
              ])
            )
          ]
        )
      )
    );
  }

  Widget _buildScoreChart(BuildContext context) {
    if (_taskscore == null) return Container(height: 121);

    List<Widget> bars = [];

    double barWidth = MediaQuery.of(context).size.width / widget.event.totalTasks - 6;

    for (int i = 0; i < _taskscore.length; i++) {
      bars.add(Column(
        children: <Widget>[
          Stack(children: <Widget>[
            Container(
              width: barWidth,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[300]
              ),
            ),
            Container(
              width: barWidth,
              height: _taskscore[i].value,
              decoration: BoxDecoration(
                color: Colors.green
              ),
            )
          ],
          alignment: AlignmentDirectional(0, 1)),
          Text(_taskscore[i].key, overflow: TextOverflow.fade)
        ],
      ));
    }

    // Add fake tasks when needed
    for (int i = 0; i < widget.event.totalTasks - _taskscore.length; i++) {
      bars.add(Column(
        children: <Widget>[
          Container(
            width: barWidth,
            height: 100,
            decoration: BoxDecoration(
                color: Colors.grey[300]
            ),
          ),
          Text("")
        ],
      ));
    }

    return Container(
      padding: EdgeInsets.fromLTRB(3, 5, 3, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: bars
      )
    );
  }

  Widget _buildSubmissionList(BuildContext context) {
    if (_subs == null) return Container();

    List<Widget> ret = [
      Center(child: Text("Time", style: TextStyle(fontWeight: FontWeight.bold))),
      Center(child: Text("Task", style: TextStyle(fontWeight: FontWeight.bold))),
      Center(child: Text("Score", style: TextStyle(fontWeight: FontWeight.bold))),
      Center(child: Text("Δ", style: TextStyle(fontWeight: FontWeight.bold)))
    ];

//    ret.add(TableRow(
//      children: <Widget>[
//
//      ],
//    ));
//
    int prevDay = -1;
    for (var s in _subs) {
      if (s.day != prevDay) {
        ret.add(Center(child: Text("Day " + s.day.toString(), style: TextStyle(fontStyle: FontStyle.italic))));
        ret.add(Container());
        ret.add(Container());
        ret.add(Container());
        prevDay = s.day;
      }
      ret.add(Center(child: Text(s.relTimeString())));
      ret.add(Center(child: Text(s.task)));
      ret.add(Center(child: Text(s.score().toStringAsFixed(2))));
      ret.add(Center(child: Text(s.delta > 0 ? "+" + s.delta.toStringAsFixed(2) : "", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),)));
    }

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(5),
      crossAxisCount: 4,
      childAspectRatio: 4,
      children: ret
    );
  }
}