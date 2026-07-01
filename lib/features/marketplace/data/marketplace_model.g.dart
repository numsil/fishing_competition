// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MarketplaceItem _$MarketplaceItemFromJson(Map<String, dynamic> json) =>
    _MarketplaceItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toInt(),
      imageUrls:
          (json['image_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      category: json['category'] as String? ?? '기타',
      status: json['status'] as String? ?? 'selling',
      tradeType: json['trade_type'] as String? ?? 'sell',
      location: json['location'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$MarketplaceItemToJson(_MarketplaceItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'title': instance.title,
      'description': instance.description,
      'price': instance.price,
      'image_urls': instance.imageUrls,
      'category': instance.category,
      'status': instance.status,
      'trade_type': instance.tradeType,
      'location': instance.location,
      'created_at': instance.createdAt.toIso8601String(),
    };
