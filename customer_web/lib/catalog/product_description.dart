/// A run of description text. Text is only ever displayed, never treated as a
/// link or HTML.
class DescriptionSpan {
  const DescriptionSpan(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  bool operator ==(Object other) =>
      other is DescriptionSpan && other.text == text && other.bold == bold;

  @override
  int get hashCode => Object.hash(text, bold);

  @override
  String toString() => bold ? '**$text**' : text;
}

sealed class DescriptionBlock {
  const DescriptionBlock();
}

class DescriptionParagraph extends DescriptionBlock {
  const DescriptionParagraph(this.spans);

  final List<DescriptionSpan> spans;
}

class DescriptionBulletList extends DescriptionBlock {
  const DescriptionBulletList(this.items);

  final List<List<DescriptionSpan>> items;
}

final _bullet = RegExp(r'^\s*[-*]\s+(.*\S)\s*$');
final _bold = RegExp(r'\*\*(.+?)\*\*');

List<DescriptionSpan> _spans(String text) {
  final spans = <DescriptionSpan>[];
  var position = 0;
  for (final match in _bold.allMatches(text)) {
    if (match.start > position) {
      spans.add(DescriptionSpan(text.substring(position, match.start)));
    }
    spans.add(DescriptionSpan(match.group(1)!, bold: true));
    position = match.end;
  }
  if (position < text.length) {
    spans.add(DescriptionSpan(text.substring(position)));
  }
  return spans;
}

/// Formats the Markdown subset used in product descriptions: paragraphs, line
/// breaks, `**bold**` and `-` or `*` bullets. Anything else stays plain text.
List<DescriptionBlock> parseProductDescription(String source) {
  final blocks = <DescriptionBlock>[];
  final paragraph = <String>[];
  final bullets = <List<DescriptionSpan>>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(DescriptionParagraph(_spans(paragraph.join('\n'))));
    paragraph.clear();
  }

  void flushBullets() {
    if (bullets.isEmpty) return;
    blocks.add(DescriptionBulletList(List.of(bullets)));
    bullets.clear();
  }

  for (final line in source.replaceAll('\r\n', '\n').split('\n')) {
    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      flushParagraph();
      bullets.add(_spans(bullet.group(1)!));
    } else if (line.trim().isEmpty) {
      flushParagraph();
      flushBullets();
    } else {
      flushBullets();
      paragraph.add(line.trim());
    }
  }
  flushParagraph();
  flushBullets();
  return blocks;
}
