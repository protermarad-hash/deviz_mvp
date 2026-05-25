import 'package:flutter/material.dart';

// ── Enumerații ────────────────────────────────────────────────────────────────

enum TaskCategorie {
  ofertare,
  programare,
  financiar,
  apel,
  email,
  intern,
  altele;

  String get label {
    switch (this) {
      case TaskCategorie.ofertare:
        return 'De ofertat';
      case TaskCategorie.programare:
        return 'Programare';
      case TaskCategorie.financiar:
        return 'Financiar';
      case TaskCategorie.apel:
        return 'Apel telefonic';
      case TaskCategorie.email:
        return 'Email';
      case TaskCategorie.intern:
        return 'Intern';
      case TaskCategorie.altele:
        return 'Altele';
    }
  }

  String get emoji {
    switch (this) {
      case TaskCategorie.ofertare:
        return '📋';
      case TaskCategorie.programare:
        return '📅';
      case TaskCategorie.financiar:
        return '💰';
      case TaskCategorie.apel:
        return '📞';
      case TaskCategorie.email:
        return '✉️';
      case TaskCategorie.intern:
        return '🏢';
      case TaskCategorie.altele:
        return '📌';
    }
  }

  static TaskCategorie fromString(String? value) {
    return TaskCategorie.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskCategorie.altele,
    );
  }
}

enum TaskPrioritate {
  urgent,
  normal,
  scazuta;

  String get label {
    switch (this) {
      case TaskPrioritate.urgent:
        return 'Urgent';
      case TaskPrioritate.normal:
        return 'Normal';
      case TaskPrioritate.scazuta:
        return 'Scăzută';
    }
  }

  Color get color {
    switch (this) {
      case TaskPrioritate.urgent:
        return Colors.red.shade600;
      case TaskPrioritate.normal:
        return Colors.amber.shade700;
      case TaskPrioritate.scazuta:
        return Colors.green.shade600;
    }
  }

  String get emoji {
    switch (this) {
      case TaskPrioritate.urgent:
        return '🔴';
      case TaskPrioritate.normal:
        return '🟡';
      case TaskPrioritate.scazuta:
        return '🟢';
    }
  }

  static TaskPrioritate fromString(String? value) {
    return TaskPrioritate.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskPrioritate.normal,
    );
  }
}

// ── Model principal ───────────────────────────────────────────────────────────

class AppTask {
  const AppTask({
    required this.id,
    required this.titlu,
    this.descriere,
    required this.categorie,
    required this.prioritate,
    required this.createdAt,
    this.deadline,
    required this.completed,
    this.completedAt,
    required this.createdBy,
  });

  final String id;
  final String titlu;
  final String? descriere;
  final TaskCategorie categorie;
  final TaskPrioritate prioritate;
  final DateTime createdAt;
  final DateTime? deadline;
  final bool completed;
  final DateTime? completedAt;
  final String createdBy;

  // ── Proprietăți derivate ───────────────────────────────────────────────────

  bool get isOverdue {
    if (completed || deadline == null) return false;
    return deadline!.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (completed || deadline == null) return false;
    final now = DateTime.now();
    return deadline!.year == now.year &&
        deadline!.month == now.month &&
        deadline!.day == now.day;
  }

  bool get isDueTomorrow {
    if (completed || deadline == null) return false;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return deadline!.year == tomorrow.year &&
        deadline!.month == tomorrow.month &&
        deadline!.day == tomorrow.day;
  }

  String get deadlineLabel {
    if (deadline == null) return '';
    if (isOverdue) {
      final diff = DateTime.now().difference(deadline!).inDays;
      return 'Depășit cu $diff zile';
    }
    if (isDueToday) return 'Azi';
    if (isDueTomorrow) return 'Mâine';
    return '${deadline!.day.toString().padLeft(2, '0')}.${deadline!.month.toString().padLeft(2, '0')}.${deadline!.year}';
  }

  // ── Serializare ────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'titlu': titlu,
        'descriere': descriere ?? '',
        'categorie': categorie.name,
        'prioritate': prioritate.name,
        'created_at': createdAt.toIso8601String(),
        'deadline': deadline?.toIso8601String(),
        'completed': completed,
        'completed_at': completedAt?.toIso8601String(),
        'created_by': createdBy,
      };

  factory AppTask.fromMap(Map<String, dynamic> map) {
    return AppTask(
      id: (map['id'] as String? ?? '').trim(),
      titlu: (map['titlu'] as String? ?? '').trim(),
      descriere: (map['descriere'] as String? ?? '').trim().isEmpty
          ? null
          : (map['descriere'] as String).trim(),
      categorie: TaskCategorie.fromString(map['categorie'] as String?),
      prioritate: TaskPrioritate.fromString(map['prioritate'] as String?),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      deadline: DateTime.tryParse(map['deadline'] as String? ?? ''),
      completed: map['completed'] == true,
      completedAt:
          DateTime.tryParse(map['completed_at'] as String? ?? ''),
      createdBy: (map['created_by'] as String? ?? '').trim(),
    );
  }

  AppTask copyWith({
    String? id,
    String? titlu,
    String? descriere,
    TaskCategorie? categorie,
    TaskPrioritate? prioritate,
    DateTime? createdAt,
    DateTime? deadline,
    bool? completed,
    DateTime? completedAt,
    String? createdBy,
    bool clearDeadline = false,
    bool clearCompletedAt = false,
    bool clearDescriere = false,
  }) {
    return AppTask(
      id: id ?? this.id,
      titlu: titlu ?? this.titlu,
      descriere: clearDescriere ? null : (descriere ?? this.descriere),
      categorie: categorie ?? this.categorie,
      prioritate: prioritate ?? this.prioritate,
      createdAt: createdAt ?? this.createdAt,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      completed: completed ?? this.completed,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppTask && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

// ── Sortare standard ──────────────────────────────────────────────────────────

List<AppTask> sortTasksActive(List<AppTask> tasks) {
  final result = List<AppTask>.from(tasks);
  result.sort((a, b) {
    // 1. Urgente primele
    final pa = a.prioritate.index;
    final pb = b.prioritate.index;
    if (pa != pb) return pa.compareTo(pb);
    // 2. Depășite înainte
    if (a.isOverdue && !b.isOverdue) return -1;
    if (!a.isOverdue && b.isOverdue) return 1;
    // 3. Deadline cel mai apropiat
    if (a.deadline != null && b.deadline != null) {
      return a.deadline!.compareTo(b.deadline!);
    }
    if (a.deadline != null) return -1;
    if (b.deadline != null) return 1;
    // 4. Cele mai recente
    return b.createdAt.compareTo(a.createdAt);
  });
  return result;
}

List<AppTask> sortTasksCompleted(List<AppTask> tasks) {
  final result = List<AppTask>.from(tasks);
  result.sort((a, b) {
    final ca = a.completedAt ?? a.createdAt;
    final cb = b.completedAt ?? b.createdAt;
    return cb.compareTo(ca); // descendent
  });
  return result;
}
