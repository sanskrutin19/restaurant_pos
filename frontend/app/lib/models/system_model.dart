import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_model.freezed.dart';
part 'system_model.g.dart';

@freezed
class KitchenCounter with _$KitchenCounter {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory KitchenCounter({
    int? id,
    required String name,
    @Default(true) bool isActive,
    @Default('store') String icon,
    @Default('#000000') String color,
    @Default('network') String printerType,
    String? printerAddress,
    @Default(9100) int printerPort,
  }) = _KitchenCounter;

  factory KitchenCounter.fromJson(Map<String, dynamic> json) => _$KitchenCounterFromJson(json);
}

@freezed
class Role with _$Role {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Role({
    int? id,
    required String name,
    Map<String, dynamic>? permissions,
  }) = _Role;

  factory Role.fromJson(Map<String, dynamic> json) => _$RoleFromJson(json);
}
