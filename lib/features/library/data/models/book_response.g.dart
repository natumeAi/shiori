// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookResponse _$BookResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_BookResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['book']);
      final val = _BookResponse(
        book: $checkedConvert(
          'book',
          (v) => Book.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$BookResponseToJson(_BookResponse instance) =>
    <String, dynamic>{'book': instance.book.toJson()};
