import 'package:flutter_test/flutter_test.dart';
import 'package:norve_customer_web/catalog/product_description.dart';

List<DescriptionSpan> paragraph(DescriptionBlock block) =>
    (block as DescriptionParagraph).spans;

List<List<DescriptionSpan>> bullets(DescriptionBlock block) =>
    (block as DescriptionBulletList).items;

void main() {
  test('formats the live watch description shape', () {
    final blocks = parseProductDescription(
      'A statement of understated elegance.\n\n'
      '**Highlights:**\n'
      '- Minimalist all-black design\n'
      '- Matte black finish',
    );
    expect(blocks, hasLength(3));
    expect(paragraph(blocks[0]), [
      const DescriptionSpan('A statement of understated elegance.'),
    ]);
    expect(paragraph(blocks[1]), [
      const DescriptionSpan('Highlights:', bold: true),
    ]);
    expect(bullets(blocks[2]), [
      [const DescriptionSpan('Minimalist all-black design')],
      [const DescriptionSpan('Matte black finish')],
    ]);
  });

  test('plain text stays one paragraph', () {
    final blocks = parseProductDescription('High-top sneakers.');
    expect(paragraph(blocks.single), [
      const DescriptionSpan('High-top sneakers.'),
    ]);
  });

  test('empty descriptions produce nothing', () {
    expect(parseProductDescription(''), isEmpty);
    expect(parseProductDescription('  \n\n '), isEmpty);
  });

  test('blank lines split paragraphs and single newlines stay line breaks', () {
    final blocks = parseProductDescription('One\nTwo\n\nThree');
    expect(blocks, hasLength(2));
    expect(paragraph(blocks[0]), [const DescriptionSpan('One\nTwo')]);
    expect(paragraph(blocks[1]), [const DescriptionSpan('Three')]);
  });

  test('handles Windows line endings', () {
    final blocks = parseProductDescription('One\r\n\r\n- Two');
    expect(blocks, hasLength(2));
    expect(bullets(blocks[1]).single.single.text, 'Two');
  });

  test('bold works inside text and inside bullets', () {
    expect(paragraph(parseProductDescription('A **b** c').single), [
      const DescriptionSpan('A '),
      const DescriptionSpan('b', bold: true),
      const DescriptionSpan(' c'),
    ]);
    expect(
      bullets(parseProductDescription('* **Soft** cotton').single).single,
      [
        const DescriptionSpan('Soft', bold: true),
        const DescriptionSpan(' cotton'),
      ],
    );
  });

  test('a bold line is not mistaken for a star bullet', () {
    expect(
      parseProductDescription('**Fabric:** Linen').single,
      isA<DescriptionParagraph>(),
    );
  });

  test('a hyphen or star without a space stays plain text', () {
    for (final text in ['-5 degrees', '*note', 'well-made']) {
      expect(parseProductDescription(text).single, isA<DescriptionParagraph>());
    }
  });

  test('unmatched markers stay as written', () {
    expect(paragraph(parseProductDescription('A **b').single), [
      const DescriptionSpan('A **b'),
    ]);
  });

  test('links, headings and HTML stay plain text and are not interpreted', () {
    for (final text in [
      '[click](https://evil.example)',
      '# Heading',
      '<script>alert(1)</script>',
    ]) {
      expect(paragraph(parseProductDescription(text).single), [
        DescriptionSpan(text),
      ]);
    }
  });

  test('a paragraph after bullets starts a new block', () {
    final blocks = parseProductDescription('- One\nAfter');
    expect(blocks, hasLength(2));
    expect(blocks[0], isA<DescriptionBulletList>());
    expect(blocks[1], isA<DescriptionParagraph>());
  });
}
