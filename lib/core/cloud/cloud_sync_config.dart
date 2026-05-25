class CloudSyncConfig {
  const CloudSyncConfig({
    this.enabled = false,
    this.provider = 'pending',
    this.projectId,
    this.region,
  });

  final bool enabled;
  final String provider;
  final String? projectId;
  final String? region;

  CloudSyncConfig copyWith({
    bool? enabled,
    String? provider,
    String? projectId,
    String? region,
  }) {
    return CloudSyncConfig(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      projectId: projectId ?? this.projectId,
      region: region ?? this.region,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'enabled': enabled,
        'provider': provider,
        'projectId': projectId,
        'region': region,
      };

  factory CloudSyncConfig.fromMap(Map<String, dynamic> map) {
    return CloudSyncConfig(
      enabled: map['enabled'] == true,
      provider: (map['provider'] as String?) ?? 'pending',
      projectId: map['projectId'] as String?,
      region: map['region'] as String?,
    );
  }
}

