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

/// Markdown-style link segment [text](url).
class MarkdownLinkSegment extends ContentSegment {
  const MarkdownLinkSegment({required this.text, required this.url});

  /// The display text.
  final String text;

  /// The URL.
  final String url;

  @override
  String get raw => '[$text]($url)';

  @override
  String toString() => 'MarkdownLinkSegment($text -> $url)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownLinkSegment &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          url == other.url;

  @override
  int get hashCode => Object.hash(text, url);
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

/// Cashtag segment ($BTC, $USD, etc.).
class CashtagSegment extends ContentSegment {
  const CashtagSegment(this.symbol);

  /// The symbol without the $ prefix (e.g., "BTC", "USD").
  final String symbol;

  @override
  String get raw => '\$$symbol';

  @override
  String toString() => 'CashtagSegment($symbol)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashtagSegment && runtimeType == other.runtimeType && symbol == other.symbol;

  @override
  int get hashCode => symbol.hashCode;
}

/// Legacy mention segment (#[0], #[1]) for NIP-08/NIP-27 compatibility.
class LegacyMentionSegment extends ContentSegment {
  const LegacyMentionSegment(this.index);

  /// The index into the event's tags array.
  final int index;

  @override
  String get raw => '#[$index]';

  @override
  String toString() => 'LegacyMentionSegment($index)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LegacyMentionSegment && runtimeType == other.runtimeType && index == other.index;

  @override
  int get hashCode => index.hashCode;
}

/// Inline code segment (backtick-wrapped code).
class InlineCodeSegment extends ContentSegment {
  const InlineCodeSegment(this.code);

  /// The code content (without backticks).
  final String code;

  @override
  String get raw => '`$code`';

  @override
  String toString() => 'InlineCodeSegment($code)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineCodeSegment && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Multi-line code block segment (triple backtick-wrapped).
class CodeBlockSegment extends ContentSegment {
  const CodeBlockSegment({required this.code, this.language});

  /// The code content (without backticks).
  final String code;

  /// Optional language identifier (e.g., "dart", "python").
  final String? language;

  @override
  String get raw => '```${language ?? ''}\n$code\n```';

  @override
  String toString() => 'CodeBlockSegment(${language ?? 'plain'}: ${code.length} chars)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeBlockSegment &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          language == other.language;

  @override
  int get hashCode => Object.hash(code, language);
}

/// Custom emoji segment (NIP-30) - :emoji_name:.
class CustomEmojiSegment extends ContentSegment {
  const CustomEmojiSegment({required this.name, this.imageUrl});

  /// The emoji shortcode (without colons).
  final String name;

  /// The URL to the emoji image (from event tags).
  final String? imageUrl;

  @override
  String get raw => ':$name:';

  @override
  String toString() => 'CustomEmojiSegment($name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomEmojiSegment &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          imageUrl == other.imageUrl;

  @override
  int get hashCode => Object.hash(name, imageUrl);
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

/// YouTube video URL segment.
class YouTubeSegment extends ContentSegment {
  const YouTubeSegment({required this.url, required this.videoId});

  /// The original YouTube URL.
  final String url;

  /// The extracted video ID.
  final String videoId;

  @override
  String get raw => url;

  @override
  String toString() => 'YouTubeSegment($videoId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YouTubeSegment &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          videoId == other.videoId;

  @override
  int get hashCode => Object.hash(url, videoId);
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

/// Checks if a URL is a YouTube URL.
///
/// Returns true for:
/// - youtube.com/watch?v=...
/// - youtu.be/...
/// - youtube.com/shorts/...
/// - youtube.com/embed/...
/// - youtube.com/v/...
bool isYouTubeUrl(String url) {
  return url.contains('youtube.com/watch') ||
      url.contains('youtu.be/') ||
      url.contains('youtube.com/shorts/') ||
      url.contains('youtube.com/embed/') ||
      url.contains('youtube.com/v/');
}

/// Extracts the video ID from a YouTube URL.
///
/// Returns null if the URL is not a valid YouTube URL or the ID cannot be extracted.
String? extractYouTubeVideoId(String url) {
  // youtube.com/watch?v=VIDEO_ID
  final watchPattern = RegExp(r'youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})');
  var match = watchPattern.firstMatch(url);
  if (match != null) return match.group(1);

  // youtu.be/VIDEO_ID
  final shortPattern = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})');
  match = shortPattern.firstMatch(url);
  if (match != null) return match.group(1);

  // youtube.com/shorts/VIDEO_ID
  final shortsPattern = RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})');
  match = shortsPattern.firstMatch(url);
  if (match != null) return match.group(1);

  // youtube.com/embed/VIDEO_ID
  final embedPattern = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})');
  match = embedPattern.firstMatch(url);
  if (match != null) return match.group(1);

  // youtube.com/v/VIDEO_ID
  final vPattern = RegExp(r'youtube\.com/v/([a-zA-Z0-9_-]{11})');
  match = vPattern.firstMatch(url);
  if (match != null) return match.group(1);

  return null;
}

/// Parser for Nostr content.
///
/// Parses raw content strings into a list of typed [ContentSegment]s
/// that can be rendered by a UI framework.
class NostrContentParser {
  /// Creates a new parser instance.
  ///
  /// [emojiTags] is an optional map of emoji shortcodes to image URLs
  /// for NIP-30 custom emoji support. The map keys should NOT include colons.
  const NostrContentParser({this.emojiTags = const {}});

  /// Map of emoji shortcodes to image URLs for NIP-30 custom emojis.
  final Map<String, String> emojiTags;

  /// Regex to match unpaired UTF-16 surrogates.
  /// - High surrogate (0xD800-0xDBFF) not followed by low surrogate
  /// - Low surrogate (0xDC00-0xDFFF) not preceded by high surrogate
  static final _unpairedSurrogateRegex = RegExp(
    r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]',
  );

  /// Sanitizes text by replacing invalid UTF-16 sequences with the replacement character.
  /// This prevents "Invalid argument(s): string is not well-formed UTF-16" errors.
  static String sanitizeText(String text) {
    return text.replaceAll(_unpairedSurrogateRegex, '\uFFFD');
  }

  /// Normalizes newlines: collapse 3+ consecutive newlines to 2, trim lines.
  static String normalizeNewlines(String text) {
    // First, normalize line endings and trim each line
    final lines = text.split('\n').map((line) => line.trim()).toList();
    final normalized = lines.join('\n');

    // Collapse 3+ consecutive newlines to exactly 2
    return normalized.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  // Image file extensions
  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'};

  // Video file extensions
  static const _videoExtensions = {'.mp4', '.webm', '.mov', '.avi', '.mkv'};

  // Code block regex - triple backticks with optional language (must match BEFORE URLs/inline code)
  static final _codeBlockRegex = RegExp(
    r'```(\w*)\n?([\s\S]*?)```',
    multiLine: true,
  );

  // Inline code regex - single backticks (not inside code blocks)
  static final _inlineCodeRegex = RegExp(r'`([^`\n]+)`');

  // Markdown link regex - [text](url) - must match BEFORE bare URLs
  static final _markdownLinkRegex = RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)');

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

  // Legacy mention regex - #[0], #[1], etc. (NIP-08/NIP-27)
  static final _legacyMentionRegex = RegExp(r'#\[(\d+)\]');

  // Hashtag regex - matches #hashtag (but NOT #[0] legacy mentions)
  static final _hashtagRegex = RegExp(r'#([a-zA-Z][a-zA-Z0-9_]*)');

  // Cashtag regex - matches $BTC, $USD, etc. (2-5 uppercase letters)
  static final _cashtagRegex = RegExp(r'\$([A-Z]{2,5})\b');

  // Custom emoji regex - :emoji_name: (NIP-30)
  static final _customEmojiRegex = RegExp(r':([a-zA-Z0-9_]+):');

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

    // Sanitize content to remove invalid UTF-16 sequences before parsing
    var sanitizedContent = sanitizeText(content);

    // Normalize newlines (collapse 3+ to 2, trim lines)
    sanitizedContent = normalizeNewlines(sanitizedContent);

    final segments = <ContentSegment>[];
    final matches = <_Match>[];

    // Find code blocks FIRST (highest priority - they can contain anything)
    for (final match in _codeBlockRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(
        match.start,
        match.end,
        _MatchType.codeBlock,
        match.group(0)!,
        extra: match.group(1), // language
        extra2: match.group(2), // code content
      ));
    }

    // Find inline code (second priority)
    for (final match in _inlineCodeRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(
        match.start,
        match.end,
        _MatchType.inlineCode,
        match.group(0)!,
        extra: match.group(1), // code content
      ));
    }

    // Find markdown links BEFORE bare URLs
    for (final match in _markdownLinkRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(
        match.start,
        match.end,
        _MatchType.markdownLink,
        match.group(0)!,
        extra: match.group(1), // display text
        extra2: match.group(2), // url
      ));
    }

    // Find all URL matches
    for (final match in _urlRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(match.start, match.end, _MatchType.url, match.group(0)!));
    }

    // Find all Nostr entity matches
    for (final match in _nostrEntityRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(match.start, match.end, _MatchType.nostrEntity, match.group(0)!));
    }

    // Find legacy mentions BEFORE hashtags (they look like #[0])
    for (final match in _legacyMentionRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(
        match.start,
        match.end,
        _MatchType.legacyMention,
        match.group(0)!,
        extra: match.group(1), // index
      ));
    }

    // Find all hashtag matches
    for (final match in _hashtagRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(match.start, match.end, _MatchType.hashtag, match.group(0)!));
    }

    // Find all cashtag matches
    for (final match in _cashtagRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(
        match.start,
        match.end,
        _MatchType.cashtag,
        match.group(0)!,
        extra: match.group(1), // symbol without $
      ));
    }

    // Find custom emojis
    for (final match in _customEmojiRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(
        match.start,
        match.end,
        _MatchType.customEmoji,
        match.group(0)!,
        extra: match.group(1), // emoji name without colons
      ));
    }

    // Find all Lightning invoice matches
    for (final match in _lightningRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(match.start, match.end, _MatchType.lightning, match.group(0)!));
    }

    // Find all newline matches
    for (final match in _newlineRegex.allMatches(sanitizedContent)) {
      matches.add(_Match(match.start, match.end, _MatchType.newline, match.group(0)!));
    }

    // Sort matches by start position, then by priority (earlier in enum = higher priority)
    matches.sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      if (startCompare != 0) return startCompare;
      // For same start position, prefer higher priority (lower enum index)
      return a.type.index.compareTo(b.type.index);
    });

    // Remove overlapping matches (keep first/highest priority occurrence)
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
        final text = sanitizedContent.substring(currentIndex, match.start);
        if (text.isNotEmpty) {
          segments.add(TextSegment(text));
        }
      }

      // Add the matched segment
      switch (match.type) {
        case _MatchType.codeBlock:
          final language = match.extra?.isNotEmpty == true ? match.extra : null;
          final code = match.extra2 ?? '';
          segments.add(CodeBlockSegment(code: code.trim(), language: language));
        case _MatchType.inlineCode:
          segments.add(InlineCodeSegment(match.extra ?? ''));
        case _MatchType.markdownLink:
          final text = match.extra ?? '';
          final url = match.extra2 ?? '';
          segments.add(MarkdownLinkSegment(text: text, url: url));
        case _MatchType.url:
          segments.add(_createUrlSegment(match.value));
        case _MatchType.nostrEntity:
          segments.add(_createMentionSegment(match.value));
        case _MatchType.legacyMention:
          final index = int.tryParse(match.extra ?? '0') ?? 0;
          segments.add(LegacyMentionSegment(index));
        case _MatchType.hashtag:
          // Extract tag without #
          final tag = match.value.substring(1);
          segments.add(HashtagSegment(tag));
        case _MatchType.cashtag:
          segments.add(CashtagSegment(match.extra ?? ''));
        case _MatchType.customEmoji:
          final name = match.extra ?? '';
          final imageUrl = emojiTags[name];
          segments.add(CustomEmojiSegment(name: name, imageUrl: imageUrl));
        case _MatchType.lightning:
          segments.add(LightningSegment(match.value));
        case _MatchType.newline:
          // Cap newlines at 2 (already normalized, but just in case)
          final count = match.value.length > 2 ? 2 : match.value.length;
          segments.add(NewlineSegment(count));
      }

      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < sanitizedContent.length) {
      final text = sanitizedContent.substring(currentIndex);
      if (text.isNotEmpty) {
        segments.add(TextSegment(text));
      }
    }

    return segments;
  }

  /// Creates a URL, Image, Video, or YouTube segment based on the URL content/extension.
  ContentSegment _createUrlSegment(String url) {
    // Smart URL cleanup with parentheses balancing
    var cleanUrl = _cleanUrl(url);

    // Check for YouTube URLs first
    if (isYouTubeUrl(cleanUrl)) {
      final videoId = extractYouTubeVideoId(cleanUrl);
      if (videoId != null) {
        return YouTubeSegment(url: cleanUrl, videoId: videoId);
      }
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

  /// Cleans a URL by removing trailing punctuation while balancing parentheses.
  ///
  /// Handles cases like:
  /// - `(https://example.com)` -> removes trailing `)` only if unbalanced in URL
  /// - `https://example.com/path_(foo)` -> keeps balanced parentheses
  /// - `https://example.com.` -> removes trailing `.`
  String _cleanUrl(String url) {
    var cleanUrl = url;

    // Remove trailing punctuation that's clearly not part of URL
    while (cleanUrl.isNotEmpty) {
      final lastChar = cleanUrl[cleanUrl.length - 1];

      // Always remove these trailing characters
      if (lastChar == ',' || lastChar == '.' || lastChar == ';' ||
          lastChar == ':' || lastChar == '!' || lastChar == '?') {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
        continue;
      }

      // For parentheses and brackets, check balance
      if (lastChar == ')') {
        final openCount = '('.allMatches(cleanUrl).length;
        final closeCount = ')'.allMatches(cleanUrl).length;
        if (closeCount > openCount) {
          cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
          continue;
        }
      }

      if (lastChar == ']') {
        final openCount = '['.allMatches(cleanUrl).length;
        final closeCount = ']'.allMatches(cleanUrl).length;
        if (closeCount > openCount) {
          cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
          continue;
        }
      }

      // No more cleanup needed
      break;
    }

    return cleanUrl;
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

  /// Extracts all cashtags from the content.
  List<String> extractCashtags(String content) {
    final segments = parse(content);
    return segments
        .whereType<CashtagSegment>()
        .map((s) => s.symbol)
        .toList();
  }

  /// Extracts all mentions from the content.
  List<MentionSegment> extractMentions(String content) {
    final segments = parse(content);
    return segments.whereType<MentionSegment>().toList();
  }

  /// Extracts all legacy mentions from the content.
  List<LegacyMentionSegment> extractLegacyMentions(String content) {
    final segments = parse(content);
    return segments.whereType<LegacyMentionSegment>().toList();
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
        case LegacyMentionSegment():
          buffer.write('#[${segment.index}]');
        case HashtagSegment():
          buffer.write('#${segment.tag}');
        case CashtagSegment():
          buffer.write('\$${segment.symbol}');
        case InlineCodeSegment():
          buffer.write(segment.code);
        case CodeBlockSegment():
          buffer.write(segment.code);
        case CustomEmojiSegment():
          buffer.write(':${segment.name}:');
        case MarkdownLinkSegment():
          buffer.write(segment.text);
        case UrlSegment():
        case ImageSegment():
        case VideoSegment():
        case LightningSegment():
        case YouTubeSegment():
          // Skip media, invoices, and YouTube in plain text
          break;
      }
    }
    return buffer.toString().trim();
  }
}

/// Internal match type - order matters for priority (lower index = higher priority).
enum _MatchType {
  codeBlock, // Highest priority - contains anything
  inlineCode,
  markdownLink, // Before bare URLs
  url,
  nostrEntity,
  legacyMention, // Before hashtags
  hashtag,
  cashtag,
  customEmoji,
  lightning,
  newline,
}

/// Internal match representation.
class _Match {
  const _Match(this.start, this.end, this.type, this.value, {this.extra, this.extra2});

  final int start;
  final int end;
  final _MatchType type;
  final String value;
  final String? extra;
  final String? extra2;
}
