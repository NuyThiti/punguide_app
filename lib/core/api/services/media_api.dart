import '../../network/api_client.dart';
import '../models/json.dart';
import '../models/media.dart';
import '../models/trip.dart';
import 'upload_form.dart';

/// A trip's image gallery and its cover.
class MediaApi {
  const MediaApi(this._client);

  final PlunoApiClient _client;

  /// One page of the gallery, newest first. The only paginated list in the API.
  Future<MediaGallery> gallery(
    String tripId, {
    int? page,
    int? limit,
  }) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/trips/$tripId/media',
      query: <String, dynamic>{'page': page, 'limit': limit},
    );
    return MediaGallery.fromJson(Json.asMap(body));
  }

  /// Uploads a photo, up to 15 MB.
  ///
  /// Attach it to a stop with [activityId] — which must belong to this trip —
  /// and the item's source becomes `activity` instead of `user_upload`.
  Future<Media> upload(
    String tripId, {
    String? filePath,
    List<int>? bytes,
    String? filename,
    String? activityId,
    String? altText,
    String? caption,
  }) async {
    final form = await buildUploadForm(
      filePath: filePath,
      bytes: bytes,
      filename: filename,
      fields: <String, String>{
        if (activityId != null) 'activityId': activityId,
        if (altText != null) 'altText': altText,
        if (caption != null) 'caption': caption,
      },
    );
    final body = await _client.upload<Map<String, dynamic>>(
      '/trips/$tripId/media',
      form: form,
    );
    return Media.fromJson(Json.asMap(body));
  }

  /// Pulls a place's own photo into the gallery.
  Future<Media> addFromPlace(
    String tripId, {
    required String placeId,
    String? activityId,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/trips/$tripId/media/from-place',
      body: Json.compact(<String, dynamic>{
        'placeId': placeId,
        'activityId': activityId,
      }),
    );
    return Media.fromJson(Json.asMap(body));
  }

  /// Edits the caption, alt text, or crop centre.
  Future<Media> update(
    String tripId,
    String mediaId, {
    String? altText,
    String? caption,
    FocalPoint? focalPoint,
  }) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/trips/$tripId/media/$mediaId',
      body: Json.compact(<String, dynamic>{
        'altText': altText,
        'caption': caption,
        'focalPoint': focalPoint?.toJson(),
      }),
    );
    return Media.fromJson(Json.asMap(body));
  }

  Future<void> delete(String tripId, String mediaId) =>
      _client.delete<void>('/trips/$tripId/media/$mediaId');

  /// Sets the cover image. Returns the whole trip, ready to replace state with.
  Future<ApiTrip> setCover(String tripId, String mediaId) async {
    final body = await _client.put<Map<String, dynamic>>(
      '/trips/$tripId/cover',
      body: <String, dynamic>{'mediaId': mediaId},
    );
    return ApiTrip.fromJson(Json.asMap(body));
  }
}
