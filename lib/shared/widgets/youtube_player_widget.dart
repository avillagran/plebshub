import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// A widget that plays YouTube videos from a URL.
///
/// Supports the following URL formats:
/// - https://www.youtube.com/watch?v=VIDEO_ID
/// - https://youtu.be/VIDEO_ID
/// - https://youtube.com/watch?v=VIDEO_ID
class YouTubePlayerWidget extends StatefulWidget {
  const YouTubePlayerWidget({
    required this.url,
    super.key,
    this.autoPlay = false,
  });

  /// The YouTube video URL.
  final String url;

  /// Whether to auto-play the video when loaded.
  final bool autoPlay;

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget> {
  YoutubePlayerController? _controller;
  String? _errorMessage;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(YouTubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    final videoId = _extractVideoId(widget.url);

    if (videoId == null) {
      setState(() {
        _errorMessage = 'Invalid YouTube URL';
        _controller = null;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: widget.autoPlay,
        ),
      )..addListener(_onPlayerStateChange);
    });
  }

  void _onPlayerStateChange() {
    if (_controller != null && _controller!.value.isReady && !_isPlayerReady) {
      setState(() {
        _isPlayerReady = true;
      });
    }
  }

  /// Extracts the video ID from various YouTube URL formats.
  ///
  /// Supported formats:
  /// - https://www.youtube.com/watch?v=VIDEO_ID
  /// - https://youtu.be/VIDEO_ID
  /// - https://youtube.com/watch?v=VIDEO_ID
  /// - https://www.youtube.com/embed/VIDEO_ID
  /// - https://www.youtube.com/v/VIDEO_ID
  String? _extractVideoId(String url) {
    // Use the built-in converter from the package
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null && videoId.isNotEmpty) {
      return videoId;
    }

    // Manual fallback parsing for edge cases
    try {
      final uri = Uri.parse(url);

      // Handle youtu.be short URLs
      if (uri.host == 'youtu.be' || uri.host == 'www.youtu.be') {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          return pathSegments.first;
        }
      }

      // Handle youtube.com URLs
      if (uri.host.contains('youtube.com')) {
        // Check for ?v= parameter
        final vParam = uri.queryParameters['v'];
        if (vParam != null && vParam.isNotEmpty) {
          return vParam;
        }

        // Check for /embed/ or /v/ paths
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 2) {
          if (pathSegments[0] == 'embed' || pathSegments[0] == 'v') {
            return pathSegments[1];
          }
        }
      }
    } on FormatException {
      // URL parsing failed
      return null;
    }

    return null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_controller == null) {
      return _buildLoadingWidget();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Theme.of(context).colorScheme.primary,
          progressColors: ProgressBarColors(
            playedColor: Theme.of(context).colorScheme.primary,
            handleColor: Theme.of(context).colorScheme.primary,
            bufferedColor:
                Theme.of(context).colorScheme.primary.withAlpha(77),
            backgroundColor: Colors.grey.shade300,
          ),
          onReady: () {
            setState(() {
              _isPlayerReady = true;
            });
          },
          onEnded: (metaData) {
            // Video ended - could add callback here if needed
          },
        ),
        builder: (context, player) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 21 / 9,
                child: player,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return AspectRatio(
      aspectRatio: 21 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return AspectRatio(
      aspectRatio: 21 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Failed to load video',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'URL: ${widget.url}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension to check if a string is a valid YouTube URL.
extension YouTubeUrlValidator on String {
  /// Returns true if this string appears to be a YouTube URL.
  bool get isYouTubeUrl {
    try {
      final uri = Uri.parse(this);
      return uri.host.contains('youtube.com') ||
          uri.host == 'youtu.be' ||
          uri.host == 'www.youtu.be';
    } on FormatException {
      return false;
    }
  }

  /// Attempts to extract a YouTube video ID from this string.
  /// Returns null if not a valid YouTube URL.
  String? get youTubeVideoId => YoutubePlayer.convertUrlToId(this);
}
