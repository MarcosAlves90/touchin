typedef JsonMap = Map<String, dynamic>;

class ContractParsingException implements Exception {
  ContractParsingException(this.message);

  final String message;

  @override
  String toString() => 'ContractParsingException(message: $message)';
}

JsonMap requireJsonMap(dynamic value, String path) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue),
    );
  }
  throw ContractParsingException('$path must be a JSON object.');
}

List<dynamic> requireJsonList(dynamic value, String path) {
  if (value is List) {
    return value;
  }
  throw ContractParsingException('$path must be a JSON array.');
}

String requireString(JsonMap json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw ContractParsingException('$key must be a string.');
}

String? optionalString(JsonMap json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw ContractParsingException('$key must be a string when present.');
}

bool requireBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw ContractParsingException('$key must be a boolean.');
}

int requireInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw ContractParsingException('$key must be a number.');
}

double requireDouble(JsonMap json, String key) {
  final value = json[key];
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw ContractParsingException('$key must be a number.');
}

DateTime requireDateTime(JsonMap json, String key) {
  final value = requireString(json, key);
  final parsedValue = DateTime.tryParse(value);
  if (parsedValue == null) {
    throw ContractParsingException('$key must be an ISO-8601 datetime.');
  }
  return parsedValue.toLocal();
}

DateTime? optionalDateTime(JsonMap json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ContractParsingException('$key must be an ISO-8601 datetime string.');
  }
  final parsedValue = DateTime.tryParse(value);
  if (parsedValue == null) {
    throw ContractParsingException('$key must be an ISO-8601 datetime.');
  }
  return parsedValue.toLocal();
}
