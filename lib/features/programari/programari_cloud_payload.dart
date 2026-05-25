Map<String, dynamic> buildProgramareCloudPayload(
  Map<String, dynamic> input,
) {
  return <String, dynamic>{
    'id': (input['id'] ?? '').toString(),
    'jobId': (input['jobId'] ?? '').toString(),
    'title': (input['title'] ?? '').toString(),
    'client': (input['client'] ?? '').toString(),
    'location': (input['location'] ?? '').toString(),
    'teamId': (input['teamId'] ?? '').toString(),
    'teamLabel': (input['teamLabel'] ?? '').toString(),
    'status': (input['status'] ?? '').toString(),
    'date': (input['date'] ?? '').toString(),
    'notes': (input['notes'] ?? '').toString(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

