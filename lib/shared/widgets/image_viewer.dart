import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

/// A full-screen image viewer with zoom capabilities.
///
/// Displays a single image in a full-screen overlay with:
/// - Pinch-to-zoom and pan (via InteractiveViewer)
/// - Double-tap to toggle zoom
/// - Close button in top corner
/// - Tap outside to close
/// - Swipe down to close
/// - Keyboard support (Escape to close)
///
/// Example:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => ImageViewer(
///     imageUrl: 'https://example.com/image.jpg',
///   ),
/// );
/// ```
class ImageViewer extends StatefulWidget {
  /// Creates an ImageViewer widget.
  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.onClose,
  });

  /// The URL of the image to display.
  final String imageUrl;

  /// Optional hero tag for Hero animation transitions.
  final Object? heroTag;

  /// Callback when the viewer is closed.
  final VoidCallback? onClose;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  final _transformationController = TransformationController();
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;

  // Track vertical drag for swipe-to-close
  double _verticalDragOffset = 0;
  double _opacity = 1.0;
  bool _isDragging = false;

  // Double-tap zoom states
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;
  static const double _doubleTapScale = 2.5;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.addListener(_onAnimationUpdate);
    // Request focus for keyboard events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _animationController.removeListener(_onAnimationUpdate);
    _animationController.dispose();
    _transformationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onAnimationUpdate() {
    if (_animation != null) {
      _transformationController.value = _animation!.value;
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    if (currentScale > _minScale) {
      // Zoom out to original
      _animateToScale(_minScale);
    } else {
      // Zoom in to the tapped position
      _animateToScale(_doubleTapScale, focalPoint: details.localPosition);
    }
  }

  void _animateToScale(double targetScale, {Offset? focalPoint}) {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    Matrix4 targetMatrix;

    if (targetScale == _minScale) {
      targetMatrix = Matrix4.identity();
    } else {
      // Calculate the focal point in the original coordinate space
      final size = context.size ?? Size.zero;
      final focal = focalPoint ?? Offset(size.width / 2, size.height / 2);

      // Create a matrix that scales around the focal point
      targetMatrix = Matrix4.identity()
        ..translate(focal.dx, focal.dy)
        ..scale(targetScale / currentScale)
        ..translate(-focal.dx, -focal.dy);

      // Apply to current transformation
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

  void _handleVerticalDragStart(DragStartDetails details) {
    // Only allow drag when not zoomed
    if (_transformationController.value.getMaxScaleOnAxis() <= _minScale) {
      _isDragging = true;
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _verticalDragOffset += details.delta.dy;
      // Calculate opacity based on drag distance
      _opacity = (1 - (_verticalDragOffset.abs() / 300)).clamp(0.2, 1.0);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    _isDragging = false;

    // Close if dragged far enough or with enough velocity
    if (_verticalDragOffset.abs() > 100 ||
        details.velocity.pixelsPerSecond.dy.abs() > 500) {
      _close();
    } else {
      // Reset position
      setState(() {
        _verticalDragOffset = 0;
        _opacity = 1.0;
      });
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
    }
    return KeyEventResult.ignored;
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            color: AppColors.background.withOpacity(_opacity * 0.95),
            child: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image with zoom and pan
                  GestureDetector(
                    onDoubleTapDown: _handleDoubleTap,
                    onVerticalDragStart: _handleVerticalDragStart,
                    onVerticalDragUpdate: _handleVerticalDragUpdate,
                    onVerticalDragEnd: _handleVerticalDragEnd,
                    child: Transform.translate(
                      offset: Offset(0, _verticalDragOffset),
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: _minScale,
                        maxScale: _maxScale,
                        panEnabled: true,
                        scaleEnabled: true,
                        onInteractionStart: (_) {
                          // Stop any running animation
                          _animationController.stop();
                        },
                        child: Center(
                          child: _buildImage(),
                        ),
                      ),
                    ),
                  ),

                  // Close button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _CloseButton(onPressed: _close),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    Widget imageWidget = CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
      errorWidget: (context, url, error) => _buildErrorWidget(),
    );

    // Wrap with Hero if tag is provided
    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    // Prevent tap from closing when tapping on image
    return GestureDetector(
      onTap: () {}, // Absorb tap
      child: imageWidget,
    );
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
