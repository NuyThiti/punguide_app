import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/api/models/trip_content.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/models/post_draft.dart';
import 'widgets/create_post_header.dart';
import 'widgets/photo_source_sheet.dart';
import 'widgets/place_pin_picker.dart';
import 'widgets/post_audience_chip.dart';
import 'widgets/post_block.dart';
import 'widgets/post_trip_row.dart';
import 'widgets/trip_link_picker.dart';

/// "สร้างโพสต์" — the community composer, from the create sheet's Post row.
///
/// A post is one or more sections, each led by its story and carrying whatever
/// the writer added to it: a heading, a photo, a pinned place. Publishing is
/// the header's เผยแพร่ and nothing else.
///
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  /// One section to start. "เพิ่มเนื้อหา" appends, and every section past the
  /// first can be removed again.
  final List<_BlockFields> _blocks = <_BlockFields>[_BlockFields()];

  PostAudience _audience = PostAudience.public;
  PostTripLink? _trip;
  String? _tripDestination;

  final _picker = ImagePicker();
  String? _draftId;
  bool _publishing = false;
  final Map<String, Media> _uploaded = {};
  String? _coverPath;
  String? _savedCoverId;

  void _syncCover() {
    final photos = _blocks.expand((block) => block.imagePaths);
    if (!photos.contains(_coverPath)) {
      _coverPath = photos.isEmpty ? null : photos.first;
    }
  }

  @override
  void initState() {
    super.initState();
    // เผยแพร่ lights up as soon as there is something to post, so what is
    // typed has to be listened to rather than read on build alone.
    for (final block in _blocks) {
      block.listen(_refresh);
    }
  }

  @override
  void dispose() {
    for (final block in _blocks) {
      block.dispose(_refresh);
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  PostDraft get _draft => PostDraft(
        audience: _audience,
        topics: _blocks
            .map((fields) => fields.toTopic())
            .where((topic) => !topic.isEmpty)
            .toList(growable: false),
        trip: _trip,
      );

  void _addBlock() {
    if (_blocks.length >= 100) {
      _message('เพิ่มเนื้อหาได้สูงสุด 100 ส่วน');
      return;
    }
    final fields = _BlockFields()..listen(_refresh);
    setState(() => _blocks.add(fields));
  }

  void _removeBlock(int index) {
    final fields = _blocks[index];
    setState(() {
      _blocks.removeAt(index);
      _syncCover();
    });
    fields.dispose(_refresh);
  }

  /// Puts the heading field on screen and drops the caret in it.
  void _addTitle(int index) {
    setState(() => _blocks[index].showTitle = true);
    _blocks[index].titleFocus.requestFocus();
  }

  void _clearTitle(int index) {
    setState(() {
      _blocks[index]
        ..showTitle = false
        ..title.clear();
    });
  }

  Future<void> _pickAudience() async {
    final picked = await showAudiencePicker(context, _audience);
    if (picked == null || !mounted) return;
    setState(() => _audience = picked);
  }

  Future<void> _pickPhoto(int index) async {
    final block = _blocks[index];
    if (block.imagePaths.length >= 20) {
      _message('เพิ่มรูปได้สูงสุด 20 รูปต่อส่วน');
      return;
    }
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null || !mounted || !_blocks.contains(block)) return;
      if (_blocks.any((fields) => fields.imagePaths.contains(image.path))) {
        _message('รูปนี้อยู่ในโพสต์แล้ว');
        return;
      }
      setState(() {
        block.imagePaths.add(image.path);
        _syncCover();
      });
    } catch (_) {
      // A denied permission, or no camera on the device.
      _message('เลือกรูปไม่สำเร็จ ลองอีกครั้ง');
    }
  }

  Future<void> _pickPlace(int index) async {
    final block = _blocks[index];
    final place = await showPlacePinPicker(context);
    if (place == null || !mounted || !_blocks.contains(block)) return;
    setState(() => block.place = place);
  }

  Future<void> _pickTrip() async {
    final link = await showTripLinkPicker(context);
    if (link == null || !mounted) return;
    if (link == noTripLink) {
      setState(() {
        _trip = null;
        _tripDestination = null;
      });
      return;
    }
    try {
      final api = await ref.read(plunoApiProvider.future);
      final trip = await api.trips.byId(link.id);
      if (!mounted) return;
      setState(() {
        _trip = link;
        _tripDestination = trip.destination;
      });
    } catch (_) {
      if (mounted) _message('โหลดข้อมูลทริปไม่สำเร็จ กรุณาลองอีกครั้ง');
    }
  }

  String _trimForTripField(String value) {
    final trimmed = value.trim();
    return trimmed.length <= 200 ? trimmed : trimmed.substring(0, 200);
  }

  String _titleForPublish(PostDraft draft) {
    if (_trip != null && _trip!.title.trim().isNotEmpty) {
      return _trimForTripField(_trip!.title);
    }
    for (final topic in draft.topics) {
      if (topic.title.trim().isNotEmpty) {
        return _trimForTripField(topic.title);
      }
      if (topic.body.trim().isNotEmpty) {
        return _trimForTripField(topic.body);
      }
    }
    return 'โพสต์ใหม่';
  }

  String _destinationForPublish(PostDraft draft) {
    final linkedDestination = _tripDestination?.trim();
    if (linkedDestination != null && linkedDestination.isNotEmpty) {
      return _trimForTripField(linkedDestination);
    }
    for (final topic in draft.topics) {
      final place = topic.place;
      if (place == null) continue;
      if (place.area != null && place.area!.trim().isNotEmpty) {
        return _trimForTripField(place.area!);
      }
      if (place.name.trim().isNotEmpty) {
        return _trimForTripField(place.name);
      }
    }
    return 'ไม่ระบุจุดหมาย';
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  Future<void> _publish() async {
    if (_publishing || !_draft.isPublishable) return;
    if (_audience == PostAudience.followers) {
      _message('ขณะนี้รองรับสาธารณะและเฉพาะฉัน กรุณาเลือกผู้ชมอีกครั้ง');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = _draft;
    final title = _titleForPublish(draft);
    final destination = _destinationForPublish(draft);
    setState(() => _publishing = true);
    try {
      for (final topic in draft.topics) {
        TripContent(
                title: topic.title,
                content: topic.body,
                mapId: topic.place?.mapId)
            .toJson();
        if (topic.place != null && topic.place!.mapId == null) {
          throw const FormatException(
              'สถานที่นี้ไม่มีรหัสแผนที่ กรุณาลบหรือเลือกสถานที่ใหม่');
        }
      }
      final api = await ref.read(plunoApiProvider.future);
      if (_draftId == null) {
        final created =
            await api.trips.createDraft(title: title, destination: destination);
        _draftId = created.id;
      }
      final contents = <TripContent>[];
      for (final topic in draft.topics) {
        final images = <String>[];
        for (final path in topic.photos) {
          if (!_uploaded.containsKey(path)) {
            final media = await api.media.upload(_draftId!, filePath: path);
            _uploaded[path] = media;
          }
          images.add(_uploaded[path]!.urls.full);
        }
        contents.add(TripContent(
            title: topic.title,
            content: topic.body,
            imageUrls: images,
            mapId: topic.place?.mapId));
      }
      final cover = _coverPath == null ? null : _uploaded[_coverPath];
      if (cover != null) {
        await api.media.setCover(_draftId!, cover.mediaId);
        _savedCoverId = cover.mediaId;
      } else if (_savedCoverId != null) {
        // A cover saved during a failed publish was subsequently removed.
        final removedId = _savedCoverId!;
        await api.media.delete(_draftId!, removedId);
        _uploaded.removeWhere((_, media) => media.mediaId == removedId);
        _savedCoverId = null;
      }
      await api.trips.update(_draftId!,
          title: title,
          destination: destination,
          contents: contents,
          visibility: draft.audience == PostAudience.public
              ? TripVisibility.public
              : TripVisibility.private);
      if (!mounted) return;
      setState(() => _publishing = false);
      _message('บันทึกโพสต์เรียบร้อยแล้ว');
      _close();
    } on ApiException catch (error) {
      if (mounted) {
        _message(
            '${_draftId == null ? '' : 'ยังเผยแพร่ไม่สำเร็จ ลองอีกครั้งได้: '}${error.message}');
      }
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return AppFrame(
      background: AppColors.screen,
      child: PopScope(
        canPop: !_publishing,
        child: AbsorbPointer(
          absorbing: _publishing,
          child: SafeArea(
            child: Column(
              children: [
                CreatePostHeader(
                  onClose: _close,
                  onPublish: _publish,
                  canPublish: !_publishing && _draft.isPublishable,
                ),
                if (_publishing) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    children: [
                      PostAuthorRow(
                        session: session,
                        audience: _audience,
                        onChangeAudience: _pickAudience,
                      ),
                      const SizedBox(height: 20),
                      for (var index = 0; index < _blocks.length; index++) ...[
                        if (index > 0)
                          const Divider(height: 30, color: AppColors.line),
                        if (_blocks.length > 1)
                          Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('ส่วนที่ ${index + 1}'),
                                IconButton(
                                    tooltip: 'เลื่อนขึ้น',
                                    icon: const Icon(Icons.arrow_upward),
                                    onPressed: index == 0
                                        ? null
                                        : () => setState(() {
                                              final block =
                                                  _blocks.removeAt(index);
                                              _blocks.insert(index - 1, block);
                                            })),
                                IconButton(
                                    tooltip: 'เลื่อนลง',
                                    icon: const Icon(Icons.arrow_downward),
                                    onPressed: index == _blocks.length - 1
                                        ? null
                                        : () => setState(() {
                                              final block =
                                                  _blocks.removeAt(index);
                                              _blocks.insert(index + 1, block);
                                            })),
                              ]),
                        PostBlock(
                          key: ValueKey(_blocks[index]),
                          titleController: _blocks[index].title,
                          titleFocus: _blocks[index].titleFocus,
                          bodyController: _blocks[index].body,
                          showTitle: _blocks[index].showTitle,
                          imagePath: null,
                          imagePaths: _blocks[index].imagePaths,
                          coverPath: _coverPath,
                          onSelectCover: (path) =>
                              setState(() => _coverPath = path),
                          onRemoveImage: (photoIndex) => setState(() {
                            _blocks[index].imagePaths.removeAt(photoIndex);
                            _syncCover();
                          }),
                          place: _blocks[index].place,
                          onAddTitle: () => _addTitle(index),
                          onClearTitle: () => _clearTitle(index),
                          onPickImage: () => _pickPhoto(index),
                          onClearImage: () => setState(() {
                            _blocks[index].imagePaths.clear();
                            _syncCover();
                          }),
                          onPickPlace: () => _pickPlace(index),
                          onClearPlace: () =>
                              setState(() => _blocks[index].place = null),
                          onRemove:
                              index == 0 ? null : () => _removeBlock(index),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _AddBlockButton(onTap: _addBlock),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          'เพิ่มเรื่องราวส่วนถัดไป',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Divider(height: 30, color: AppColors.line),
                      PostTripRow(trip: _trip?.title, onTap: _pickTrip),
                      const Divider(height: 1, color: AppColors.line),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The controllers and attachments of one section, owned by the screen so the
/// block itself stays stateless.
class _BlockFields {
  final TextEditingController title = TextEditingController();
  final TextEditingController body = TextEditingController();
  final FocusNode titleFocus = FocusNode();

  /// The heading field has been asked for. Not the same as the heading having
  /// text: one just added is on screen and still blank.
  bool showTitle = false;

  final List<String> imagePaths = [];
  PostPlace? place;

  PostTopic toTopic() => PostTopic(
        title: title.text,
        body: body.text,
        imagePaths: List.of(imagePaths),
        place: place,
      );

  void listen(VoidCallback onChanged) {
    title.addListener(onChanged);
    body.addListener(onChanged);
  }

  void dispose(VoidCallback onChanged) {
    title.removeListener(onChanged);
    body.removeListener(onChanged);
    title.dispose();
    body.dispose();
    titleFocus.dispose();
  }
}

class _AddBlockButton extends StatelessWidget {
  const _AddBlockButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 21),
        label: const Text(
          'เพิ่มเนื้อหา',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandOrange,
          side: const BorderSide(color: AppColors.brandOrange, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
