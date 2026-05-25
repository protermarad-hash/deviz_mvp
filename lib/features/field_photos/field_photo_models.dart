class FieldPhotoRecord {
  const FieldPhotoRecord({
    required this.id,
    required this.sourceModule,
    required this.sourceEntityId,
    this.documentId = '',
    this.photoType = 'altul',
    this.description = '',
    this.filePath = '',
    this.fileName = '',
    this.cloudPath = '',
    this.downloadUrl = '',
    required this.takenAt,
    this.takenByName = '',
    this.takenByUserId = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sourceModule;
  final String sourceEntityId;
  final String documentId;
  final String photoType;
  final String description;
  final String filePath;
  final String fileName;
  final String cloudPath;
  final String downloadUrl;
  final DateTime takenAt;
  final String takenByName;
  final String takenByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  FieldPhotoRecord copyWith({
    String? id,
    String? sourceModule,
    String? sourceEntityId,
    String? documentId,
    String? photoType,
    String? description,
    String? filePath,
    String? fileName,
    String? cloudPath,
    String? downloadUrl,
    DateTime? takenAt,
    String? takenByName,
    String? takenByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FieldPhotoRecord(
      id: id ?? this.id,
      sourceModule: sourceModule ?? this.sourceModule,
      sourceEntityId: sourceEntityId ?? this.sourceEntityId,
      documentId: documentId ?? this.documentId,
      photoType: photoType ?? this.photoType,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      cloudPath: cloudPath ?? this.cloudPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      takenAt: takenAt ?? this.takenAt,
      takenByName: takenByName ?? this.takenByName,
      takenByUserId: takenByUserId ?? this.takenByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'source_module': sourceModule,
      'source_entity_id': sourceEntityId,
      'document_id': documentId,
      'photo_type': photoType,
      'description': description,
      'file_path': filePath,
      'file_name': fileName,
      'cloud_path': cloudPath,
      'download_url': downloadUrl,
      'taken_at': takenAt.toIso8601String(),
      'taken_by_name': takenByName,
      'taken_by_user_id': takenByUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FieldPhotoRecord.fromMap(Map<String, dynamic> map) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value == null) {
          continue;
        }
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
      return '';
    }

    DateTime pickDate(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value == null) {
          continue;
        }
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) {
          return parsed;
        }
      }
      return DateTime.now();
    }

    return FieldPhotoRecord(
      id: pick(const <String>['id']),
      sourceModule: pick(
        const <String>['source_module', 'sourceModule'],
      ),
      sourceEntityId: pick(
        const <String>['source_entity_id', 'sourceEntityId'],
      ),
      documentId: pick(
        const <String>['document_id', 'documentId'],
      ),
      photoType: pick(
        const <String>['photo_type', 'photoType'],
      ),
      description: pick(
        const <String>['description'],
      ),
      filePath: pick(
        const <String>['file_path', 'filePath'],
      ),
      fileName: pick(
        const <String>['file_name', 'fileName'],
      ),
      cloudPath: pick(
        const <String>['cloud_path', 'cloudPath'],
      ),
      downloadUrl: pick(
        const <String>['download_url', 'downloadUrl'],
      ),
      takenAt: pickDate(
        const <String>['taken_at', 'takenAt'],
      ),
      takenByName: pick(
        const <String>['taken_by_name', 'takenByName'],
      ),
      takenByUserId: pick(
        const <String>['taken_by_user_id', 'takenByUserId'],
      ),
      createdAt: pickDate(
        const <String>['created_at', 'createdAt'],
      ),
      updatedAt: pickDate(
        const <String>['updated_at', 'updatedAt'],
      ),
    );
  }
}

enum FieldPhotoType {
  inainte,
  dupa,
  defect,
  serie,
  montaj,
  pif,
  garantie,
  agfr,
  altul,
}

extension FieldPhotoTypeX on FieldPhotoType {
  String get key {
    switch (this) {
      case FieldPhotoType.inainte:
        return 'inainte';
      case FieldPhotoType.dupa:
        return 'dupa';
      case FieldPhotoType.defect:
        return 'defect';
      case FieldPhotoType.serie:
        return 'serie';
      case FieldPhotoType.montaj:
        return 'montaj';
      case FieldPhotoType.pif:
        return 'pif';
      case FieldPhotoType.garantie:
        return 'garantie';
      case FieldPhotoType.agfr:
        return 'agfr';
      case FieldPhotoType.altul:
        return 'altul';
    }
  }

  String get label {
    switch (this) {
      case FieldPhotoType.inainte:
        return 'Inainte';
      case FieldPhotoType.dupa:
        return 'Dupa';
      case FieldPhotoType.defect:
        return 'Defect';
      case FieldPhotoType.serie:
        return 'Serie';
      case FieldPhotoType.montaj:
        return 'Montaj';
      case FieldPhotoType.pif:
        return 'PIF';
      case FieldPhotoType.garantie:
        return 'Garantie';
      case FieldPhotoType.agfr:
        return 'AGFR';
      case FieldPhotoType.altul:
        return 'Altul';
    }
  }

  static FieldPhotoType fromKey(String raw) {
    final value = raw.trim().toLowerCase();
    for (final type in FieldPhotoType.values) {
      if (type.key == value) {
        return type;
      }
    }
    return FieldPhotoType.altul;
  }
}
