// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$KitchenCounterImpl _$$KitchenCounterImplFromJson(Map<String, dynamic> json) =>
    _$KitchenCounterImpl(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      icon: json['icon'] as String? ?? 'store',
      color: json['color'] as String? ?? '#000000',
      printerType: json['printer_type'] as String? ?? 'network',
      printerAddress: json['printer_address'] as String?,
      printerPort: (json['printer_port'] as num?)?.toInt() ?? 9100,
    );

Map<String, dynamic> _$$KitchenCounterImplToJson(
        _$KitchenCounterImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'is_active': instance.isActive,
      'icon': instance.icon,
      'color': instance.color,
      'printer_type': instance.printerType,
      'printer_address': instance.printerAddress,
      'printer_port': instance.printerPort,
    };

_$RoleImpl _$$RoleImplFromJson(Map<String, dynamic> json) => _$RoleImpl(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      permissions: json['permissions'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$RoleImplToJson(_$RoleImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'permissions': instance.permissions,
    };
