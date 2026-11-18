import 'package:touchin_flutter/contracts/contract_parsing.dart';

class TaskRecommendation {
  const TaskRecommendation({required this.taskId, required this.taskName});

  final String taskId;
  final String taskName;

  factory TaskRecommendation.fromJson(JsonMap json) => TaskRecommendation(
        taskId: requireString(json, 'taskId'),
        taskName: requireString(json, 'taskName'),
      );
}

class TaskRecommendations {
  const TaskRecommendations({required this.status, required this.items});

  final String status;
  final List<TaskRecommendation> items;

  factory TaskRecommendations.fromJson(JsonMap json) => TaskRecommendations(
        status: requireString(json, 'status'),
        items: requireJsonList(json['recommendations'], 'recommendations')
            .map((item) => TaskRecommendation.fromJson(
                  requireJsonMap(item, 'recommendations[]'),
                ))
            .toList(growable: false),
      );
}
