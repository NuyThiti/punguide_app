import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
/// There is no posts endpoint yet, so [_publish] assembles the [PostDraft] the
/// API will take and reports that publishing is not open rather than dropping
/// it quietly.
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

  final _picker = ImagePicker();

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
    final fields = _BlockFields()..listen(_refresh);
    setState(() => _blocks.add(fields));
  }

  void _removeBlock(int index) {
    final fields = _blocks[index];
    setState(() => _blocks.removeAt(index));
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
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null || !mounted) return;
      setState(() => _blocks[index].imagePath = image.path);
    } catch (_) {
      // A denied permission, or no camera on the device.
      _message('เลือกรูปไม่สำเร็จ ลองอีกครั้ง');
    }
  }

  Future<void> _pickPlace(int index) async {
    final place = await showPlacePinPicker(context);
    if (place == null || !mounted) return;
    setState(() => _blocks[index].place = place);
  }

  Future<void> _pickTrip() async {
    final link = await showTripLinkPicker(context);
    if (link == null || !mounted) return;
    setState(() => _trip = link == noTripLink ? null : link);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  /// Everything the composer collected, ready for the endpoint that will take
  /// it. Until then the writer is told, not left guessing.
  void _publish() {
    if (!_draft.isPublishable) {
      _message('เขียนเนื้อหาหรือใส่รูปก่อนเผยแพร่');
      return;
    }
    _message('เผยแพร่โพสต์ยังไม่เปิดใช้งาน');
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
      child: SafeArea(
        child: Column(
          children: [
            CreatePostHeader(
              onClose: _close,
              onPublish: _publish,
              canPublish: _draft.isPublishable,
            ),
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
                    PostBlock(
                      key: ValueKey(_blocks[index]),
                      titleController: _blocks[index].title,
                      titleFocus: _blocks[index].titleFocus,
                      bodyController: _blocks[index].body,
                      showTitle: _blocks[index].showTitle,
                      imagePath: _blocks[index].imagePath,
                      place: _blocks[index].place,
                      onAddTitle: () => _addTitle(index),
                      onClearTitle: () => _clearTitle(index),
                      onPickImage: () => _pickPhoto(index),
                      onClearImage: () =>
                          setState(() => _blocks[index].imagePath = null),
                      onPickPlace: () => _pickPlace(index),
                      onClearPlace: () =>
                          setState(() => _blocks[index].place = null),
                      onRemove: index == 0 ? null : () => _removeBlock(index),
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

  String? imagePath;
  PostPlace? place;

  PostTopic toTopic() => PostTopic(
        title: title.text,
        body: body.text,
        imagePath: imagePath,
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
