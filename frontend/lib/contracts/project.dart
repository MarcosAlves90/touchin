import 'package:touchin_flutter/contracts/contract_parsing.dart';

const int projectNameMaxLength = 160;
const int projectDescriptionMaxLength = 2000;

enum ProjectStatus { active, inactive }

ProjectStatus projectStatusFromApi(String value) {
  return switch (value) {
    'active' => ProjectStatus.active,
    'inactive' => ProjectStatus.inactive,
    _ => throw ContractParsingException(
        'Unsupported project status value: $value',
      ),
  };
}

String projectStatusToApi(ProjectStatus value) {
  return switch (value) {
    ProjectStatus.active => 'active',
    ProjectStatus.inactive => 'inactive',
  };
}

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.taskEmployeeLimit,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final int taskEmployeeLimit;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProjectSummary.fromJson(JsonMap json) {
    return ProjectSummary(
      id: requireString(json, 'id'),
      name: requireString(json, 'name'),
      description: optionalString(json, 'description'),
      taskEmployeeLimit: requireInt(json, 'taskEmployeeLimit'),
      status: projectStatusFromApi(requireString(json, 'status')),
      createdAt: requireDateTime(json, 'createdAt'),
      updatedAt: requireDateTime(json, 'updatedAt'),
    );
  }
}


class ProjectMemberSummary {
  const ProjectMemberSummary({
    required this.employeeId,
    required this.projectId,
    required this.employeeName,
    required this.createdAt,
  });

  final String employeeId;
  final String projectId;
  final String employeeName;
  final DateTime createdAt;

  factory ProjectMemberSummary.fromJson(JsonMap json) {
    return ProjectMemberSummary(
      employeeId: requireString(json, 'employeeId'),
      projectId: requireString(json, 'projectId'),
      employeeName: requireString(json, 'employeeName'),
      createdAt: requireDateTime(json, 'createdAt'),
    );
  }
}

class ProjectDraft {
  const ProjectDraft({
    required this.name,
    required this.description,
    required this.taskEmployeeLimit,
    this.status = ProjectStatus.active,
  });

  final String name;
  final String description;
  final int taskEmployeeLimit;
  final ProjectStatus status;

  factory ProjectDraft.fromProject(ProjectSummary project) {
    return ProjectDraft(
      name: project.name,
      description: project.description ?? '',
      taskEmployeeLimit: project.taskEmployeeLimit,
      status: project.status,
    );
  }

  JsonMap toApiJson() {
    return <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'taskEmployeeLimit': taskEmployeeLimit,
      'status': projectStatusToApi(status),
    };
  }
}
