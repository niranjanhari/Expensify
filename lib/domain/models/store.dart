class Store {
  final String id;
  final String name;
  final String normalizedName;
  final String? defaultTagId;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // Attached relations (optional)
  final String? defaultTagName;

  Store({
    required this.id,
    required this.name,
    required this.normalizedName,
    this.defaultTagId,
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.defaultTagName,
  });

  static String normalizeStoreName(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'normalized_name': normalizedName,
      'default_tag_id': defaultTagId,
      'usage_count': usageCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as String,
      name: map['name'] as String,
      normalizedName: map['normalized_name'] as String,
      defaultTagId: map['default_tag_id'] as String?,
      usageCount: (map['usage_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
      defaultTagName: map['default_tag_name'] as String?,
    );
  }
}
