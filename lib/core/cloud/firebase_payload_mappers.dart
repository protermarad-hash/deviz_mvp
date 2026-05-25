import '../auth/field_auth_models.dart';

Map<String, dynamic> firebaseUserPayload(FieldAuthUser user) {
  return <String, dynamic>{
    'id': user.id,
    'name': user.name,
    'email': user.email.trim().toLowerCase(),
    'role': user.role.name,
    'active': user.active,
    'employee_id': user.employeeId,
    'teamId': user.teamId,
    'phone': user.phone,
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

Map<String, dynamic> firebaseTeamPayload(Map<String, dynamic> team) {
  return <String, dynamic>{
    'id': (team['id'] ?? '').toString(),
    'name': (team['name'] ?? '').toString(),
    'members': team['members'] ?? const <dynamic>[],
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

Map<String, dynamic> firebaseJobPayload(Map<String, dynamic> job) {
  return <String, dynamic>{
    'id': (job['id'] ?? '').toString(),
    'code': (job['code'] ?? job['jobCode'] ?? '').toString(),
    'title': (job['title'] ?? job['name'] ?? '').toString(),
    'clientId': (job['clientId'] ?? '').toString(),
    'location': (job['location'] ?? '').toString(),
    'status': (job['status'] ?? '').toString(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

Map<String, dynamic> firebaseClientPayload(Map<String, dynamic> client) {
  return <String, dynamic>{
    'id': (client['id'] ?? '').toString(),
    'name': (client['name'] ?? '').toString(),
    'email': (client['email'] ?? '').toString(),
    'phone': (client['phone'] ?? '').toString(),
    'address': (client['address'] ?? '').toString(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}
