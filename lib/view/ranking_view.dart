import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import 'participant_view.dart';

import '../model/Event.dart';
import '../model/Participant.dart';
import '../data.dart';

class Ranking extends StatefulWidget {
  final Event event;
  const Ranking({Key key, this.event}) : super(key: key);

  @override
  _RankingState createState() => new _RankingState();
}

class _RankingState extends State<Ranking> {
  List<Participant> _ranking;
  bool _searching = false;
  TextEditingController _searchController = TextEditingController();

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final ScrollController _rankingController = ScrollController(keepScrollOffset: false);

  _RankingState() {

  }

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((_){  _refreshIndicatorKey.currentState?.show(); } );
    _refreshRanking();

    _searchController.addListener(() {
//      _searchController.
      _performSearch();
    });
  }

  void _performSearch() {
    var s = _searchController.text.toLowerCase();

    for (var i = 0; i < _ranking.length; i++) {
      if (_ranking[i].title().toLowerCase().contains(s) || widget.event.teams[_ranking[i].team].toLowerCase().contains(s)) {
        _rankingController.jumpTo(49.0 * i + 0.01);
        break;
      }
    }
  }

  Future<void> _refreshRanking() async {
    await fillEventInfo(widget.event.url, widget.event);
//    var ranking = await fake_getParticipants();
    var ranking = await getParticipants(widget.event);

    _refreshIndicatorKey.currentState?.deactivate();
    if (!mounted) return;

    setState(() {
      _ranking = ranking;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _searching ? AppBar(
        backgroundColor: Colors.white,
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: "Search name or country..."),
          controller: _searchController,
        ),
        leading: InkWell(child: Icon(Icons.close, color: Colors.grey), onTap: () {
          setState(() {
            _searching = false;
          });
          _searchController.text = "";
          _performSearch();
        }),
      ) : AppBar(title: Text(widget.event.name)),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshRanking,
        child: ListView.builder(
          controller: _rankingController,
          padding: EdgeInsets.all(0),
          itemBuilder: (context, index) => InkWell(
            child: Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[300]))),
              child: Row(
                children: <Widget>[
                  Container(
                    alignment: Alignment.center,
                    width: 30,
                    child: _ranking[index].rankText(),
                  ),
                  Container(
                    child: CircleAvatar(
                      backgroundImage: _ranking[index].face,
                      backgroundColor: Colors.transparent
                    ),
                    padding: EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.grey[200], // border color
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(left: 5),
                  ),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _ranking[index].title(),
                        style: TextStyle(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 16,
                            height: 12,
                            child: widget.event.getFlag(_ranking[index].team),
                            padding: EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.rectangle
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.only(left: 2),
                          ),
                          Text(widget.event.teams[_ranking[index].team], style: TextStyle(fontSize: 12, color: Colors.black54))
                        ],
                      )
                    ]
                  )),
                  InkWell(
                    child: _ranking[index].isFavorite ?
                      Container(child: Icon(Icons.star, color: Colors.amber))
                      : Container(child: Icon(Icons.star_border, color: Colors.grey)),
                    onTap: () {
                      _ranking[index].toggleFavorite(context, _ranking[index].id + "~" + widget.event.id);
                      setState(() {});
                    },
                  ),
                  Container(
                    padding: EdgeInsets.only(right: 5),
                    child: CircularPercentIndicator(
                      radius: 30.0,
                      lineWidth: 3.0,
                      percent: _ranking[index].score / widget.event.maxScore,
                      center: Text(_ranking[index].score.toStringAsFixed(0), style: TextStyle(fontSize: 10)),
                      progressColor: Colors.green,
                    ),
                  )
                ],
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ParticipantView(event: widget.event, participant: _ranking[index])
                ),
              );
            },
          ),
          itemCount: _ranking == null ? 0 : _ranking.length
        )
      ),
      floatingActionButton: _searching ? null : FloatingActionButton(
        onPressed: () {
          setState(() {
            _searching = true;
          });
        },
        child: Icon(Icons.search),
        backgroundColor: Colors.blue,
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

class ContestSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    // TODO: implement buildActions
    return null;
  }

  @override
  Widget buildLeading(BuildContext context) {
    // TODO: implement buildLeading
    return null;
  }

  @override
  Widget buildResults(BuildContext context) {
    // TODO: implement buildResults
    return null;
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // TODO: implement buildSuggestions
    return null;
  }

}