import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

/// A full-screen image gallery viewer with navigation.
///
/// Displays multiple images in a PageView with:
/// - Swipe left/right to navigate between images
/// - Pinch-to-zoom and pan on current image
/// - Double-tap to toggle zoom
/// - Previous/Next arrow buttons on sides
/// - Current position indicator (1/5, 2/5, etc.)
/// - Keyboard navigation (left/right arrows, Escape to close)
/// - Preloads adjacent images for smooth transitions
///
/// Example:
/// ```dart
/// showDialog(
///   context: context,
///   useSafeArea: false,
///   builder: (_) => ImageGalleryViewer(
///     images: ['https://example.com/1.jpg', 'https://example.com/2.jpg'],
///     initialIndex: 0,
///   ),
/// );
/// ```
class ImageGalleryViewer extends StatefulWidget {
  /// Creates an ImageGalleryViewer widget.
  const ImageGalleryViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroTagBuilder,
    this.onClose,
  });

  /// List of image URLs to display.
  final List<String> images;

  /// Initial image index to display.
  final int initialIndex;

  /// Optional builder for hero tags based on image index.
  final Object? Function(int index)? heroTagBuilder;

  /// Callback when the viewer is closed.
  final VoidCallback? onClose;

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();

  // Track if user is currently zoomed in (to disable page swiping)
  final Map<int, TransformationController> _transformationControllers = {};
  bool _isZoomed = false;

  // Animation controllers for double-tap zoom per page
  final Map<int, AnimationController> _animationControllers = {};

  // For swipe-to-close gesture
  double _verticalDragOffset = 0;
  double _opacity = 1.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    // Request focus for keyboard events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _getTransformationController(int index) {
    return _transformationControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      // Reset zoom state when changing pages
      _isZoomed = false;
    });
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _close() {
    widget.onClose?.call();
    Navigator.of(context).pop();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _close();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _goToPrevious();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _goToNext();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    // Only allow drag when not zoomed
    if (!_isZoomed) {
      _isDragging = true;
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _verticalDragOffset += details.delta.dy;
      _opacity = (1 - (_verticalDragOffset.abs() / 300)).clamp(0.2, 1.0);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    _isDragging = false;

    if (_verticalDragOffset.abs() > 100 ||
        details.velocity.pixelsPerSecond.dy.abs() > 500) {
      _close();
    } else {
      setState(() {
        _verticalDragOffset = 0;
        _opacity = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: _close,
          onVerticalDragStart: _handleVerticalDragStart,
          onVerticalDragUpdate: _handleVerticalDragUpdate,
          onVerticalDragEnd: _handleVerticalDragEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            color: AppColors.background.withOpacity(_opacity * 0.95),
            child: SafeArea(
              child: Transform.translate(
                offset: Offset(0, _verticalDragOffset),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Page view with images
                    _buildPageView(),

                    // Top bar with close button and counter
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: _buildTopBar(),
                    ),

                    // Navigation arrows (only show if multiple images)
                    if (widget.images.length > 1) ...[
                      // Previous button
                      if (_currentIndex > 0)
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _NavigationButton(
                              icon: Icons.chevron_left,
                              onPressed: _goToPrevious,
                            ),
                          ),
                        ),
                      // Next button
                      if (_currentIndex < widget.images.length - 1)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _NavigationButton(
                              icon: Icons.chevron_right,
                              onPressed: _goToNext,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Page counter
        if (widget.images.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_currentIndex + 1} of ${widget.images.length}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          const SizedBox.shrink(),

        // Close button
        _CloseButton(onPressed: _close),
      ],
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.images.length,
      onPageChanged: _onPageChanged,
      // Disable swiping when zoomed
      physics: _isZoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      itemBuilder: (context, index) {
        return _ImagePage(
          imageUrl: widget.images[index],
          heroTag: widget.heroTagBuilder?.call(index),
          transformationController: _getTransformationController(index),
          onZoomChanged: (isZoomed) {
            if (index == _currentIndex) {
              setState(() => _isZoomed = isZoomed);
            }
          },
        );
      },
    );
  }
}

/// Individual image page with zoom capabilities.
class _ImagePage extends StatefulWidget {
  const _ImagePage({
    required this.imageUrl,
    required this.transformationController,
    required this.onZoomChanged,
    this.heroTag,
  });

  final String imageUrl;
  final Object? heroTag;
  final TransformationController transformationController;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;
  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.addListener(_onAnimationUpdate);
  }

  @override
  void dispose() {
    _animationController.removeListener(_onAnimationUpdate);
    _animationController.dispose();
    super.dispose();
  }

  void _onAnimationUpdate() {
    if (_animation != null) {
      widget.transformationController.value = _animation!.value;
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale =
        widget.transformationController.value.getMaxScaleOnAxis();

    if (currentScale > _minScale) {
      // Zoom out to original
      _animateToScale(_minScale);
      widget.onZoomChanged(false);
    } else {
      // Zoom in to the tapped position
      _animateToScale(_doubleTapScale, focalPoint: details.localPosition);
      widget.onZoomChanged(true);
    }
  }

  void _animateToScale(double targetScale, {Offset? focalPoint}) {
    final currentMatrix = widget.transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    Matrix4 targetMatrix;

    if (targetScale == _minScale) {
      targetMatrix = Matrix4.identity();
    } else {
      final size = context.size ?? Size.zero;
      final focal = focalPoint ?? Offset(size.width / 2, size.height / 2);

      targetMatrix = Matrix4.identity()
        ..translate(focal.dx, focal.dy)
        ..scale(targetScale / currentScale)
        ..translate(-focal.dx, -focal.dy);

      targetMatrix = targetMatrix.multiplied(currentMatrix);
    }

    _animation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward(from: 0);
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    final scale = widget.transformationController.value.getMaxScaleOnAxis();
    widget.onZoomChanged(scale > _minScale + 0.1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      // Absorb taps to prevent closing when tapping on image area
      onTap: () {},
      child: InteractiveViewer(
        transformationController: widget.transformationController,
        minScale: _minScale,
        maxScale: _maxScale,
        panEnabled: true,
        scaleEnabled: true,
        onInteractionStart: (_) {
          _animationController.stop();
        },
        onInteractionEnd: _onInteractionEnd,
        child: Center(
          child: _buildImage(),
        ),
      ),
    );
  }

  Widget _buildImage() {
    Widget imageWidget = CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const SizedBox(
        width: 100,
        height: 100,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => _buildErrorWidget(),
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load image',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.imageUrl,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Navigation button for prev/next.
class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withOpacity(0.7),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: AppColors.textPrimary,
            size: 32,
          ),
        ),
      ),
    );
  }
}

/// Close button with consistent styling.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withOpacity(0.8),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(
            Icons.close,
            color: AppColors.textPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Shows the image gallery viewer as a full-screen dialog.
///
/// This is a convenience function to display the [ImageGalleryViewer].
///
/// Example:
/// ```dart
/// showImageGallery(
///   context: context,
///   images: ['https://example.com/1.jpg', 'https://example.com/2.jpg'],
///   initialIndex: 0,
/// );
/// ```
Future<void> showImageGallery({
  required BuildContext context,
  required List<String> images,
  int initialIndex = 0,
  Object? Function(int index)? heroTagBuilder,
}) {
  return showDialog(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.transparent,
    builder: (_) => ImageGalleryViewer(
      images: images,
      initialIndex: initialIndex,
      heroTagBuilder: heroTagBuilder,
    ),
  );
}
