import 'package:flutter/material.dart';
import 'package:plebshub_ui/plebshub_ui.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

/// A simple, self-contained video player widget for embedding in feeds.
///
/// This widget handles its own controller lifecycle and provides basic controls
/// for play/pause, progress, and seeking. Designed for use in feeds and
/// content views where videos need to be embedded inline.
///
/// Uses `video_player_hdr` from PlebsPlayerOSS for HDR support.
class EmbeddableVideoPlayer extends StatefulWidget {
  const EmbeddableVideoPlayer({
    super.key,
    required this.url,
    this.autoPlay = false,
    this.showControls = true,
    this.aspectRatio,
  });

  /// The URL of the video to play.
  final String url;

  /// Whether to start playing automatically when initialized.
  final bool autoPlay;

  /// Whether to show playback controls.
  final bool showControls;

  /// Custom aspect ratio. If null, uses 16:9 default.
  final double? aspectRatio;

  @override
  State<EmbeddableVideoPlayer> createState() => _EmbeddableVideoPlayerState();
}

class _EmbeddableVideoPlayerState extends State<EmbeddableVideoPlayer> {
  VideoPlayerHdrController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControlsOverlay = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(EmbeddableVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isInitialized = false;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      _controller = VideoPlayerHdrController.networkUrl(
        Uri.parse(widget.url),
      );

      _controller!.addListener(_onControllerUpdate);

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      if (widget.autoPlay) {
        await _controller!.play();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final value = _controller?.value;
    if (value == null) return;

    if (value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = value.errorDescription ?? 'Unknown error';
      });
    }

    // Trigger rebuild for progress updates
    setState(() {});
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControlsOverlay = !_showControlsOverlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized || _controller == null) {
      return _buildPlaceholder();
    }

    final aspectRatio = widget.aspectRatio ?? _controller!.value.aspectRatio;

    return AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            GestureDetector(
              onTap: _toggleControlsVisibility,
              child: VideoPlayerHdr(_controller!),
            ),

            // Controls overlay
            if (widget.showControls && _showControlsOverlay)
              _buildControlsOverlay(),

            // Buffering indicator
            if (_controller!.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return AspectRatio(
      aspectRatio: widget.aspectRatio ?? 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return AspectRatio(
      aspectRatio: widget.aspectRatio ?? 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load video',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initializePlayer,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final value = _controller!.value;
    final isPlaying = value.isPlaying;
    final position = value.position;
    final duration = value.duration;

    return GestureDetector(
      onTap: _toggleControlsVisibility,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.5),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top spacer
            const SizedBox(height: 8),

            // Center play/pause button
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // Current position
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),

                  // Progress bar
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white.withOpacity(0.3),
                          backgroundColor: Colors.white.withOpacity(0.1),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // Duration
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
