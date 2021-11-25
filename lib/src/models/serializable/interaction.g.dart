// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Interaction _$InteractionFromJson(Map<String, dynamic> json) => Interaction(
      request: Request.fromJson(json['request'] as Map<String, dynamic>),
      response: Response.fromJson(json['response'] as Map<String, dynamic>),
      description: json['description'] as String?,
      providerStates: ProviderState.fromJson(
          json['providerStates'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$InteractionToJson(Interaction instance) {
  final val = <String, dynamic>{
    'request': instance.request,
    'response': instance.response,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('description', instance.description);
  val['providerStates'] = instance.providerStates;
  return val;
}
