// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_trip.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

extension GetIsarTripCollection on Isar {
  IsarCollection<IsarTrip> get isarTrips => this.collection();
}

const IsarTripSchema = CollectionSchema(
  name: r'IsarTrip',
  id: 3939607042902198608,
  properties: {
    r'budget': PropertySchema(
      id: 0,
      name: r'budget',
      type: IsarType.double,
    ),
    r'coverImage': PropertySchema(
      id: 1,
      name: r'coverImage',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'description': PropertySchema(
      id: 3,
      name: r'description',
      type: IsarType.string,
    ),
    r'destination': PropertySchema(
      id: 4,
      name: r'destination',
      type: IsarType.string,
    ),
    r'duration': PropertySchema(
      id: 5,
      name: r'duration',
      type: IsarType.long,
    ),
    r'isSaved': PropertySchema(
      id: 6,
      name: r'isSaved',
      type: IsarType.bool,
    ),
    r'title': PropertySchema(
      id: 7,
      name: r'title',
      type: IsarType.string,
    ),
    r'tripId': PropertySchema(
      id: 8,
      name: r'tripId',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 9,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },
  estimateSize: _isarTripEstimateSize,
  serialize: _isarTripSerialize,
  deserialize: _isarTripDeserialize,
  deserializeProp: _isarTripDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'tripId': IndexSchema(
      id: 7734156669642746260,
      name: r'tripId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'tripId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _isarTripGetId,
  getLinks: _isarTripGetLinks,
  attach: _isarTripAttach,
  version: '3.1.0+1',
);

int _isarTripEstimateSize(
  IsarTrip object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.coverImage.length * 3;
  bytesCount += 3 + object.description.length * 3;
  bytesCount += 3 + object.destination.length * 3;
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.tripId.length * 3;
  return bytesCount;
}

void _isarTripSerialize(
  IsarTrip object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.budget);
  writer.writeString(offsets[1], object.coverImage);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.description);
  writer.writeString(offsets[4], object.destination);
  writer.writeLong(offsets[5], object.duration);
  writer.writeBool(offsets[6], object.isSaved);
  writer.writeString(offsets[7], object.title);
  writer.writeString(offsets[8], object.tripId);
  writer.writeDateTime(offsets[9], object.updatedAt);
}

IsarTrip _isarTripDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarTrip();
  object.budget = reader.readDouble(offsets[0]);
  object.coverImage = reader.readString(offsets[1]);
  object.createdAt = reader.readDateTime(offsets[2]);
  object.description = reader.readString(offsets[3]);
  object.destination = reader.readString(offsets[4]);
  object.duration = reader.readLong(offsets[5]);
  object.isSaved = reader.readBool(offsets[6]);
  object.isarId = id;
  object.title = reader.readString(offsets[7]);
  object.tripId = reader.readString(offsets[8]);
  object.updatedAt = reader.readDateTime(offsets[9]);
  return object;
}

P _isarTripDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return reader.readDouble(offset) as P;
    case 1:
      return reader.readString(offset) as P;
    case 2:
      return reader.readDateTime(offset) as P;
    case 3:
      return reader.readString(offset) as P;
    case 4:
      return reader.readString(offset) as P;
    case 5:
      return reader.readLong(offset) as P;
    case 6:
      return reader.readBool(offset) as P;
    case 7:
      return reader.readString(offset) as P;
    case 8:
      return reader.readString(offset) as P;
    case 9:
      return reader.readDateTime(offset) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarTripGetId(IsarTrip object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _isarTripGetLinks(IsarTrip object) {
  return [];
}

void _isarTripAttach(IsarCollection<dynamic> col, Id id, IsarTrip object) {
  object.isarId = id;
}
