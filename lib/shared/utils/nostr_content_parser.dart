/// Pure Dart parser for Nostr content.
///
/// Parses Nostr content strings into typed segments for rendering.
/// This parser is framework-agnostic and can be used outside of Flutter.
library;

/// Base class for all content segments.
sealed class ContentSegment {
  const ContentSegment();

  /// The raw text of this segment.
  String get raw;
}

/// Plain text segment.
class TextSegment extends ContentSegment {
  const TextSegment(this.text);

  /// The text content.
  final String text;

  @override
  String get raw => text;

  @override
  String toString() => 'TextSegment($text)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextSegment && runtimeType == other.runtimeType && text == other.text;

  @override
  int get hashCode => text.hashCode;
}

/// URL segment (non-media link).
class UrlSegment extends ContentSegment {
  const UrlSegment(this.url);

  /// The URL.
  final String url;

  @override
  String get raw => url;

  @override
  String toString() => 'UrlSegment($url)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlSegment && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Image URL segment.
class ImageSegment extends ContentSegment {
  const ImageSegment(this.url);

  /// The image URL.
  final String url;

  @override
  String get raw => url;

  @override
  String toString() => 'ImageSegment($url)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageSegment && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Video URL segment.
class VideoSegment extends ContentSegment {
  const VideoSegment(this.url);

  /// The video URL.
  final String url;

  @override
  String get raw => url;

  @override
  String toString() => 'VideoSegment($url)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoSegment && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Nostr entity type for mentions.
enum NostrEntityType {
  /// npub - Public key
  npub,

  /// nprofile - Profile with optional relay hints
  nprofile,

  /// note - Event reference
  note,

  /// nevent - Event with optional relay hints
  nevent,

  /// naddr - Parameterized replaceable event address
  naddr,
}

/// User or profile mention segment.
class MentionSegment extends ContentSegment {
  const MentionSegment({
    required this.entityType,
    required this.bech32,
    this.pubkey,
    this.eventId,
  });

  /// The type of Nostr entity.
  final NostrEntityType entityType;

  /// The full bech32-encoded identifier.
  final String bech32;

  /// The decoded public key (for npub/nprofile).
  final String? pubkey;

  /// The decoded event ID (for note/nevent).
  final String? eventId;

  @override
  String get raw => 'nostr:$bech32';

  /// Returns a shortened display version of the bech32.
  String get shortDisplay {
    if (bech32.length <= 16) return bech32;
    return '${bech32.substring(0, 8)}...${bech32.substring(bech32.length - 4)}';
  }

  @override
  String toString() => 'MentionSegment($entityType: $bech32)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MentionSegment &&
          runtimeType == other.runtimeType &&
          entityType == other.entityType &&
          bech32 == other.bech32;

  @override
  int get hashCode => Object.hash(entityType, bech32);
}

/// Hashtag segment.
class HashtagSegment extends ContentSegment {
  const HashtagSegment(this.tag);

  /// The hashtag without the # prefix.
  final String tag;

  @override
  String get raw => '#$tag';

  @override
  String toString() => 'HashtagSegment($tag)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HashtagSegment && runtimeType == other.runtimeType && tag == other.tag;

  @override
  int get hashCode => tag.hashCode;
}

/// Lightning invoice segment.
class LightningSegment extends ContentSegment {
  const LightningSegment(this.invoice);

  /// The full Lightning invoice (lnbc...).
  final String invoice;

  @override
  String get raw => invoice;

  @override
  String toString() => 'LightningSegment($invoice)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LightningSegment &&
          runtimeType == other.runtimeType &&
          invoice == other.invoice;

  @override
  int get hashCode => invoice.hashCode;
}

/// Newline segment for explicit line breaks.
class NewlineSegment extends ContentSegment {
  const NewlineSegment([this.count = 1]);

  /// Number of consecutive newlines.
  final int count;

  @override
  String get raw => '\n' * count;

  @override
  String toString() => 'NewlineSegment($count)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewlineSegment && runtimeType == other.runtimeType && count == other.count;

  @override
  int get hashCode => count.hashCode;
}

/// Parser for Nostr content.
///
/// Parses raw content strings into a list of typed [ContentSegment]s
/// that can be rendered by a UI framework.
class NostrContentParser {
  /// Creates a new parser instance.
  const NostrContentParser();

  // Image file extensions
  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'};

  // Video file extensions
  static const _videoExtensions = {'.mp4', '.webm', '.mov', '.avi', '.mkv'};

  // URL regex - matches http/https URLs
  static final _urlRegex = RegExp(
    r'https?://[^\s<>\[\]]+',
    caseSensitive: false,
  );

  // Nostr entity regex - matches nostr:npub1..., nostr:note1..., etc.
  static final _nostrEntityRegex = RegExp(
    r'nostr:(npub1[a-z0-9]{58}|nprofile1[a-z0-9]+|note1[a-z0-9]{58}|nevent1[a-z0-9]+|naddr1[a-z0-9]+)',
    caseSensitive: false,
  );

  // Hashtag regex - matches #hashtag
  static final _hashtagRegex = RegExp(
    r'#([a-zA-Z][a-zA-Z0-9_]*)',
  );

  // Lightning invoice regex - matches lnbc... invoices
  static final _lightningRegex = RegExp(
    r'\b(lnbc[a-z0-9]+)\b',
    caseSensitive: false,
  );

  // Newline regex - matches one or more consecutive newlines
  static final _newlineRegex = RegExp(r'\n+');

  /// Parses the given content into a list of segments.
  List<ContentSegment> parse(String content) {
    if (content.isEmpty) return const [];

    final segments = <ContentSegment>[];
    final matches = <_Match>[];

    // Find all URL matches
    for (final match in _urlRegex.allMatches(content)) {
      matches.add(_Match(match.start, match.end, _MatchType.url, match.group(0)!));
    }

    // Find all Nostr entity matches
    for (final match in _nostrEntityRegex.allMatches(content)) {
      matches.add(_Match(match.start, match.end, _MatchType.nostrEntity, match.group(0)!));
    }

    // Find all hashtag matches
    for (final match in _hashtagRegex.allMatches(content)) {
      matches.add(_Match(match.start, match.end, _MatchType.hashtag, match.group(0)!));
    }

    // Find all Lightning invoice matches
    for (final match in _lightningRegex.allMatches(content)) {
      matches.add(_Match(match.start, match.end, _MatchType.lightning, match.group(0)!));
    }

    // Find all newline matches
    for (final match in _newlineRegex.allMatches(content)) {
      matches.add(_Match(match.start, match.end, _MatchType.newline, match.group(0)!));
    }

    // Sort matches by start position
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping matches (keep first occurrence)
    final filteredMatches = <_Match>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start >= lastEnd) {
        filteredMatches.add(match);
        lastEnd = match.end;
      }
    }

    // Build segments
    int currentIndex = 0;
    for (final match in filteredMatches) {
      // Add text before this match
      if (match.start > currentIndex) {
        final text = content.substring(currentIndex, match.start);
        if (text.isNotEmpty) {
          segments.add(TextSegment(text));
        }
      }

      // Add the matched segment
      switch (match.type) {
        case _MatchType.url:
          segments.add(_createUrlSegment(match.value));
        case _MatchType.nostrEntity:
          segments.add(_createMentionSegment(match.value));
        case _MatchType.hashtag:
          // Extract tag without #
          final tag = match.value.substring(1);
          segments.add(HashtagSegment(tag));
        case _MatchType.lightning:
          segments.add(LightningSegment(match.value));
        case _MatchType.newline:
          segments.add(NewlineSegment(match.value.length));
      }

      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < content.length) {
      final text = content.substring(currentIndex);
      if (text.isNotEmpty) {
        segments.add(TextSegment(text));
      }
    }

    return segments;
  }

  /// Creates a URL, Image, or Video segment based on the URL extension.
  ContentSegment _createUrlSegment(String url) {
    // Clean URL (remove trailing punctuation that might have been captured)
    var cleanUrl = url;
    while (cleanUrl.isNotEmpty &&
        (cleanUrl.endsWith(',') ||
            cleanUrl.endsWith('.') ||
            cleanUrl.endsWith(')') ||
            cleanUrl.endsWith(']'))) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    // Check file extension
    final uri = Uri.tryParse(cleanUrl);
    if (uri != null) {
      final path = uri.path.toLowerCase();
      for (final ext in _imageExtensions) {
        if (path.endsWith(ext)) {
          return ImageSegment(cleanUrl);
        }
      }
      for (final ext in _videoExtensions) {
        if (path.endsWith(ext)) {
          return VideoSegment(cleanUrl);
        }
      }
    }

    return UrlSegment(cleanUrl);
  }

  /// Creates a mention segment from a nostr: URI.
  MentionSegment _createMentionSegment(String nostrUri) {
    // Remove "nostr:" prefix
    final bech32 = nostrUri.substring(6);

    // Determine entity type
    final NostrEntityType entityType;
    if (bech32.startsWith('npub1')) {
      entityType = NostrEntityType.npub;
    } else if (bech32.startsWith('nprofile1')) {
      entityType = NostrEntityType.nprofile;
    } else if (bech32.startsWith('note1')) {
      entityType = NostrEntityType.note;
    } else if (bech32.startsWith('nevent1')) {
      entityType = NostrEntityType.nevent;
    } else if (bech32.startsWith('naddr1')) {
      entityType = NostrEntityType.naddr;
    } else {
      // Default to npub if unknown
      entityType = NostrEntityType.npub;
    }

    return MentionSegment(
      entityType: entityType,
      bech32: bech32,
    );
  }

  /// Extracts all image URLs from the content.
  List<String> extractImages(String content) {
    final segments = parse(content);
    return segments
        .whereType<ImageSegment>()
        .map((s) => s.url)
        .toList();
  }

  /// Extracts all hashtags from the content.
  List<String> extractHashtags(String content) {
    final segments = parse(content);
    return segments
        .whereType<HashtagSegment>()
        .map((s) => s.tag)
        .toList();
  }

  /// Extracts all mentions from the content.
  List<MentionSegment> extractMentions(String content) {
    final segments = parse(content);
    return segments.whereType<MentionSegment>().toList();
  }

  /// Returns plain text content with all special elements removed.
  String toPlainText(String content) {
    final segments = parse(content);
    final buffer = StringBuffer();
    for (final segment in segments) {
      switch (segment) {
        case TextSegment():
          buffer.write(segment.text);
        case NewlineSegment():
          buffer.write('\n');
        case MentionSegment():
          buffer.write('@${segment.shortDisplay}');
        case HashtagSegment():
          buffer.write('#${segment.tag}');
        case UrlSegment():
        case ImageSegment():
        case VideoSegment():
        case LightningSegment():
          // Skip media and invoices in plain text
          break;
      }
    }
    return buffer.toString().trim();
  }
}

/// Internal match type.
enum _MatchType {
  url,
  nostrEntity,
  hashtag,
  lightning,
  newline,
}

/// Internal match representation.
class _Match {
  const _Match(this.start, this.end, this.type, this.value);

  final int start;
  final int end;
  final _MatchType type;
  final String value;
}
