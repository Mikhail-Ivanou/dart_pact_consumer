// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Metadata _$MetadataFromJson(Map<String, dynamic> json) => Metadata(
      pactDart: (json['pact-dart'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {'version': '1.3.0'},
      pactSpecification:
          (json['pactSpecification'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, e as String),
              ) ??
              const {'version': '2.0.0'},
    );

Map<String, dynamic> _$MetadataToJson(Metadata instance) => <String, dynamic>{
      'pactSpecification': instance.pactSpecification,
      'pact-dart': instance.pactDart,
    };
