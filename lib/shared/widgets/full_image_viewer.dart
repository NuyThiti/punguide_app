import 'package:flutter/material.dart';

import 'cover_image.dart';

/// Opens [urls] full-screen, starting on [initialIndex].
///
/// Returns once the viewer is closed. Does nothing when there is nothing to
/// show, so a caller need not guard an empty list.
Future<void> showFullImages(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) {
  if (urls.isEmpty) return Future<void>.value();

  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      // The photo is the subject, so it fades in over the page rather than
      // sliding in as a new one.
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (_, __, ___) => _FullImageViewer(
        urls: urls,
        initialIndex: initialIndex.clamp(0, urls.length - 1),
      ),
    ),
  );
}

/// A photo at full size: uncropped, pinch to zoom, swipe between the rest.
///
/// The list crops to a fixed ratio so the spots read evenly; this is where the
/// whole picture is.
class _FullImageViewer extends StatefulWidget {
  const _FullImageViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<_FullImageViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// A zoomed photo owns the drag: panning it must not turn the page.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.urls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              itemCount: widget.urls.length,
              onPageChanged: (index) => setState(() {
                _index = index;
                _zoomed = false;
              }),
              itemBuilder: (_, index) => _ZoomablePhoto(
                url: widget.urls[index],
                onZoomChanged: (zoomed) {
                  if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _ViewerButton(
                    icon: Icons.close,
                    tooltip: 'ปิด',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (many)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      onInteractionEnd: (_) {
        // `getMaxScaleOnAxis` is 1 exactly when the photo is back to its
        // resting size, which is when the page may scroll again.
        widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01);
      },
      child: Center(
        child: CoverImage(source: widget.url, fit: BoxFit.contain),
      ),
    );
  }
}

class _ViewerButton extends StatelessWidget {
  const _ViewerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.5),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
