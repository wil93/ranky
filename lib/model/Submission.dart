class Submission {
  Submission({
    this.id,
    this.task,
    this.subScore,
    this.delta,
    this.time,
    this.relTime,
    this.day
  });

  String id;
  String task;
  List<double> subScore;
  double delta;
  int time;
  int relTime;
  int day;

  String relTimeString() {
    String ret = Duration(seconds: relTime).toString();

    return ret.substring(0, ret.indexOf("."));
  }

  double score() {
    double total = 0;

    for (var s in subScore) {
      total += s;
    }

    return total;
  }
}
