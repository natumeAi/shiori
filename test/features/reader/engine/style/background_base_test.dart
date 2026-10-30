import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';

import 'style_test_support.dart';

void main() {
  test('background URLs resolve against their declaring stylesheet', () {
    final book = EpubBook.open(
      buildEpub(
        sections: {
          'chapters/ch.xhtml': xhtml(
            head:
                '<link rel="stylesheet" href="../a/one.css"/>'
                '<link rel="stylesheet" href="../b/two.css"/>',
            body:
                '<div id="a" class="a" '
                'style="background-image:url(../a/inline.png)"></div>'
                '<div id="b" class="b"></div>',
          ),
        },
        files: {
          'a/one.css': '.a { background-image: url(tile.png); }',
          'b/two.css': '.b { background-image: url(tile.png); }',
          'a/tile.png': 'a',
          'b/tile.png': 'b',
          'a/inline.png': 'inline',
        },
      ),
    );
    final sample = StyleSample.fromBook(book);
    // Inline declarations win over the linked `.a` rule; both are local
    // targets and must be resolved against their own declaring base.
    expect(sample['a'].authored.backgroundImage, 'OEBPS/a/inline.png');
    expect(sample['b'].authored.backgroundImage, 'OEBPS/b/tile.png');
    book.archive.close();
  });
}
