class Team {
  const Team({
    required this.id,
    required this.name,
    this.leaderEmployeeId = '',
    this.memberEmployeeIds = const <String>[],
    this.notes = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String leaderEmployeeId;
  final List<String> memberEmployeeIds;
  final String notes;
  final bool active;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'leader_employee_id': leaderEmployeeId,
      'member_employee_ids': memberEmployeeIds,
      'notes': notes,
      'active': active,
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      leaderEmployeeId: (map['leader_employee_id'] ?? '').toString(),
      memberEmployeeIds: (map['member_employee_ids'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      notes: (map['notes'] ?? '').toString(),
      active: map['active'] != false,
    );
  }
}
