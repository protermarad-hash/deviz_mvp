class AppointmentMaterialKitComponent {
  const AppointmentMaterialKitComponent({
    required this.id,
    required this.materialId,
    required this.name,
    required this.unit,
    this.baseQuantity = 0,
    this.quantityPerLinearMeter = 0,
    this.unitCost = 0,
    this.isVariableLength = false,
    this.notes = '',
  });

  final String id;
  final String materialId;
  final String name;
  final String unit;
  final double baseQuantity;
  final double quantityPerLinearMeter;
  final double unitCost;
  final bool isVariableLength;
  final String notes;

  AppointmentMaterialKitComponent copyWith({
    String? id,
    String? materialId,
    String? name,
    String? unit,
    double? baseQuantity,
    double? quantityPerLinearMeter,
    double? unitCost,
    bool? isVariableLength,
    String? notes,
  }) {
    return AppointmentMaterialKitComponent(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      baseQuantity: baseQuantity ?? this.baseQuantity,
      quantityPerLinearMeter:
          quantityPerLinearMeter ?? this.quantityPerLinearMeter,
      unitCost: unitCost ?? this.unitCost,
      isVariableLength: isVariableLength ?? this.isVariableLength,
      notes: notes ?? this.notes,
    );
  }

  double resolvedQuantity(double linearMeters) {
    if (isVariableLength) {
      final meters = linearMeters < 0 ? 0.0 : linearMeters;
      return baseQuantity + (quantityPerLinearMeter * meters);
    }
    return baseQuantity;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'material_id': materialId,
      'name': name,
      'unit': unit,
      'base_quantity': baseQuantity,
      'quantity_per_linear_meter': quantityPerLinearMeter,
      'unit_cost': unitCost,
      'is_variable_length': isVariableLength,
      'notes': notes,
    };
  }

  factory AppointmentMaterialKitComponent.fromMap(Map<String, dynamic> map) {
    return AppointmentMaterialKitComponent(
      id: (map['id'] ?? '').toString().trim(),
      materialId: (map['material_id'] ?? map['materialId'] ?? '')
          .toString()
          .trim(),
      name: (map['name'] ?? '').toString().trim(),
      unit: (map['unit'] ?? '').toString().trim(),
      baseQuantity: _asDouble(map['base_quantity'] ?? map['baseQuantity']),
      quantityPerLinearMeter: _asDouble(
        map['quantity_per_linear_meter'] ?? map['quantityPerLinearMeter'],
      ),
      unitCost: _asDouble(map['unit_cost'] ?? map['unitCost']),
      isVariableLength:
          map['is_variable_length'] == true || map['isVariableLength'] == true,
      notes: (map['notes'] ?? '').toString().trim(),
    );
  }
}

class AppointmentMaterialKitTemplate {
  const AppointmentMaterialKitTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.defaultLinearMeters = 0,
    this.isActive = true,
    this.components = const <AppointmentMaterialKitComponent>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final double defaultLinearMeters;
  final bool isActive;
  final List<AppointmentMaterialKitComponent> components;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppointmentMaterialKitTemplate copyWith({
    String? id,
    String? name,
    String? description,
    double? defaultLinearMeters,
    bool? isActive,
    List<AppointmentMaterialKitComponent>? components,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentMaterialKitTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      defaultLinearMeters: defaultLinearMeters ?? this.defaultLinearMeters,
      isActive: isActive ?? this.isActive,
      components: components ?? this.components,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'default_linear_meters': defaultLinearMeters,
      'is_active': isActive,
      'components': components.map((item) => item.toMap()).toList(growable: false),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppointmentMaterialKitTemplate.fromMap(Map<String, dynamic> map) {
    final rawComponents = map['components'];
    final components = rawComponents is List
        ? rawComponents
            .map((item) {
              if (item is Map<String, dynamic>) {
                return AppointmentMaterialKitComponent.fromMap(item);
              }
              if (item is Map) {
                return AppointmentMaterialKitComponent.fromMap(
                  Map<String, dynamic>.from(item),
                );
              }
              return null;
            })
            .whereType<AppointmentMaterialKitComponent>()
            .toList(growable: false)
        : const <AppointmentMaterialKitComponent>[];
    return AppointmentMaterialKitTemplate(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      defaultLinearMeters: _asDouble(
        map['default_linear_meters'] ?? map['defaultLinearMeters'],
      ),
      isActive: map['is_active'] != false && map['isActive'] != false,
      components: components,
      createdAt: _asDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: _asDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

double _asDouble(dynamic raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
}

DateTime _asDateTime(dynamic raw) {
  final parsed = DateTime.tryParse((raw ?? '').toString().trim());
  return parsed ?? DateTime.now();
}
