class Task {
  Task({
    this.id,
    this.name,
    this.shortName,
    this.contest,
    this.order,
    this.maxScore,
    this.scorePrecision,
    this.numSubtasks
  });

  String id;
  String name;
  String shortName;
  String contest;
  int order;
  double maxScore;
  int scorePrecision;
  int numSubtasks;
}
