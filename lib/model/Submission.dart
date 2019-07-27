class Submission {
  Submission({
    this.id,
    this.task,
    this.score,
    this.delta,
    this.time,
    this.relTime,
    this.day
  });

  String id;
  String task;
  double score;
  double delta;
  int time;
  int relTime;
  int day;

  String relTimeString() {
    String ret = Duration(seconds: relTime).toString();

    return ret.substring(0, ret.indexOf("."));
  }
}
