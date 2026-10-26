"""Builds the synthetic source-edge EPUBs and trims WebKit oracle vectors.

Usage (from the repository root):

    python tool/reader/source_edge/make_edge_epubs.py build
    # run the oracle over each EPUB (see README.md), then:
    python tool/reader/source_edge/make_edge_epubs.py trim <oracle-webkit.json> <name>

All content is hand-written filler; no book text is involved.
"""
import json
import sys
import zipfile
from pathlib import Path

OUT = Path('test/fixtures/reader/source_edge')
NS = 'xmlns="http://www.w3.org/1999/xhtml"'


def x(body, head='<title>t</title>', extra=''):
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n<html {NS}{extra}>'
            f'<head>{head}</head><body>{body}</body></html>')


def package(name, secs, extra_items, nav=None, ncx=None, extra_spine=''):
    manifest = ''.join(
        f'<item id="s{i}" href="{n}" media-type="{m}"/>' for i, (n, m, c, l) in enumerate(secs))
    manifest += extra_items
    spine = ''.join(
        f'<itemref idref="s{i}" id="r{i}"' + (f' linear="{l}"' if l else '') + '/>'
        for i, (n, m, c, l) in enumerate(secs)) + extra_spine
    toc_attr = ' toc="ncx"' if ncx else ''
    opf = (
        '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
        'unique-identifier="u"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="u">x</dc:identifier><dc:title>t</dc:title>'
        '<meta property="rendition:layout">reflowable</meta></metadata>'
        f'<manifest>{manifest}</manifest><spine{toc_attr}>{spine}</spine></package>')
    with zipfile.ZipFile(OUT / f'{name}.epub', 'w') as z:
        z.writestr(zipfile.ZipInfo('mimetype'), 'application/epub+zip')
        z.writestr('META-INF/container.xml',
                   '<?xml version="1.0"?><container version="1.0" '
                   'xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>'
                   '<rootfile full-path="OEBPS/content.opf" '
                   'media-type="application/oebps-package+xml"/></rootfiles></container>')
        z.writestr('OEBPS/content.opf', opf)
        z.writestr('OEBPS/s.css', '.x{background:url(img.png)}@import "other.css";')
        z.writestr('OEBPS/img.png', b'\x89PNG\r\n\x1a\n')
        z.writestr('OEBPS/ghost.xhtml', x('<p>ghost</p>'))
        if nav:
            z.writestr('OEBPS/nav.xhtml', nav)
        if ncx:
            z.writestr('OEBPS/toc.ncx', ncx)
        for n, m, c, l in secs:
            z.writestr('OEBPS/' + n, c.encode('utf-8'))


def build_xhtml():
    secs = []

    def add(name, content, mt='application/xhtml+xml', linear=None):
        secs.append((name, mt, content, linear))

    add('b-xhtml-inert.xhtml', x('<p>a<?foo bar?>b</p><iframe id="i"><script id="s2"></script></iframe><form id="f1"><script id="s3">1</script><form id="f2"><input/></form></form><object id="o"><param name="a"/></object><base id="b" href="x"/><meta http-equiv="refresh" content="0" id="m"/><template><p>t<script/></p></template><noscript><p>ns</p></noscript>a<!--c-->b<![CDATA[ c<d ]]>e<![CDATA[]]>f', head='<title>t</title><base href="http://x/"/><meta http-equiv="x"/>'))
    add('d-namespaces.xhtml', x('<h:p xmlns:h="http://www.w3.org/1999/xhtml" xml:lang="en">a&#13;b&#x1F600;</h:p><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><image xlink:href="i.png"/><style>.a{fill:red}</style><script>1</script></svg><p xmlns="">nons</p><div><p xmlns="urn:x">other</p></div>&amp;&lt;]]&gt;&#x20;'))
    add('e-doctype.xhtml', '<?xml version="1.0"?>\n<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">\n<html xmlns="http://www.w3.org/1999/xhtml"><head><title>t</title></head><body><p>&copy; &hellip; &mdash; &eacute;&amp;</p></body></html>')
    add('e2-internal.xhtml', '<?xml version="1.0"?>\n<!DOCTYPE html [<!ENTITY foo "bar &#169;">]>\n<html xmlns="http://www.w3.org/1999/xhtml"><head><title>t</title></head><body><p>&foo;|</p></body></html>')
    add('g-styles.xhtml', '<?xml-stylesheet href="s.css" type="text/css"?>\n' + x('<p style="background:url(img.png)">a</p><img src="img.png" srcset="img.png 1x, img.png 2x"/><svg xmlns="http://www.w3.org/2000/svg"><style>@import "s.css"; .b{background:url( \'img.png\' )}</style></svg>', head='<title>t</title><link rel="stylesheet" href="s.css"/><style>\n@import "s.css";\n.a { background: url(img.png) }\n/* c */ .b { background: URL( "img.png" ) } .c{background:url(missing.png)} .d{background:url(http://x/y.png)}<![CDATA[ .e{} ]]></style><style></style><style><!-- c --></style>'))
    add('h-nonlinear.xhtml', x('<p>nonlinear</p>'), linear='no')
    bad = {
        'i1-mismatch': f'<html {NS}><head><title>t</title></head><body><p>a</div></body></html>',
        'i2-unquoted': f'<html {NS}><head><title>t</title></head><body><p class=x>a</p></body></html>',
        'i3-dupattr': f'<html {NS}><head><title>t</title></head><body><p a="1" a="2">a</p></body></html>',
        'i4-prefix': f'<html {NS}><head><title>t</title></head><body><x:p>a</x:p></body></html>',
        'i5-ltattr': f'<html {NS}><head><title>t</title></head><body><p a="<">a</p></body></html>',
        'i6-comment': f'<html {NS}><head><title>t</title></head><body><!-- a -- b --><p>a</p></body></html>',
        'i7-cdataend': f'<html {NS}><head><title>t</title></head><body><p>a ]]> b</p></body></html>',
        'i8-entity': f'<html {NS}><head><title>t</title></head><body><p>a &foo; b</p></body></html>',
        'i9-leadingws': f'\n<?xml version="1.0"?><html {NS}><head><title>t</title></head><body><p>a</p></body></html>',
        'j1-tworoots': f'<html {NS}><head><title>t</title></head><body><p>a</p></body></html><html {NS}/>',
        'j2-trailing': f'<html {NS}><head><title>t</title></head><body><p>a</p></body></html>junk',
        'j3-ctrl': f'<html {NS}><head><title>t</title></head><body><p>a\x01b</p></body></html>',
        'j4-nbsp-noq': f'<html {NS}><head><title>t</title></head><body><p>a&nbsp;b &#xA0; &#160;</p></body></html>',
        'j5-amp': f'<html {NS}><head><title>t</title></head><body><p>a & b</p></body></html>',
        'j6-badref': f'<html {NS}><head><title>t</title></head><body><p>&#0; &#xD800;</p></body></html>',
        'j7-selfclose-p': f'<html {NS}><head><title>t</title></head><body><p/><div/><br/>x<script src="a.js"/><p>y</p></body></html>',
        'j8-nsattr': f'<html {NS} xmlns:epub="http://www.idpf.org/2007/ops"><head><title>t</title></head><body epub:type="x"><p>a</p></body></html>',
        'j9-nonamespace-svg': '<svg viewBox="0 0 1 1"><text>a</text></svg>',
        'k1-noscript-bad': f'<html {NS}><head><title>t</title></head><body><noscript><img src="x.png"></noscript><p>a<br>b</body></html>',
        'k2-entities-lone': f'<html {NS}><head><title>t</title></head><body><p>&#xD800;x &#xFFFE;</p></body></html>',
    }
    for k, v in bad.items():
        add(k + '.xhtml', v)
    items = ('<item id="css" href="s.css" media-type="text/css"/>'
             '<item id="img" href="img.png" media-type="image/png"/>'
             '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
             '<item id="ghost" href="ghost.xhtml" media-type="application/xhtml+xml"/>')
    nav = x('<nav epub:type="toc"><ol><li><a href="b-xhtml-inert.xhtml">A &amp; B</a><ol><li><span>Sp</span></li></ol></li><li><a href="d-namespaces.xhtml#frag"></a></li><li><a href="c%20d.xhtml" title="T"></a></li></ol></nav>',
            extra=' xmlns:epub="http://www.idpf.org/2007/ops"')
    package('edge-xhtml', secs, items, nav=nav,
            extra_spine='<itemref idref="missing"/><itemref idref="ghost"/>')


def build_html():
    secs = []

    def add(name, content, mt='text/html'):
        secs.append((name, mt, content, None))

    h = '<!DOCTYPE html><html><head><title>t</title></head><body>'
    add('c-html.html', h + '<svg><script id="ss"></script><style>a{}</style><image xlink:href="i.png"/></svg><math><mi>x</mi></math><table><tr><td>a</table>foo<b>bar<p>q&#13;r<pre>\nfoo</pre><textarea>\nbar</textarea><form id="ff"><p>f</form><!-- c --><?php x ?></body></html>')
    add('h1-noscript-body.html', h + '<noscript><p>x &amp; y</p><img src="a.png"></noscript><p>after</p></body></html>')
    add('h2-noscript-head.html', '<!DOCTYPE html><html><head><noscript><link rel="stylesheet" href="s.css"><style>a{}</style></noscript><title>t</title></head><body><p>b</p></body></html>')
    add('h3-template-body.html', h + '<template id="tp"><p>in</p><tr><td>x</td></tr></template><p>after</p></body></html>')
    add('h4-foreign.html', h + '<svg viewBox="0 0 1 1"><foreignObject><p>f</p></foreignObject><clipPath/><image href="i.png"/></svg><image src="a.png"><math><annotation-xml encoding="text/html"><p>m</p></annotation-xml></math></body></html>')
    add('h5-implied.html', h + '<ul><li>a<li>b<ul><li>c</ul></ul><select><option>1<option>2</select><ruby>漢<rt>かん</ruby><table>foster<tr><td>c</table></body></html>')
    add('h6-cdata-pi.html', h + '<![CDATA[ x ]]><?xml version="1.0"?><?php echo 1 ?><p>a</p><!--c--><!-- - --></body></html>')
    add('h7-refs.html', h + '<p>&copy &copy; &#x80; &#128; &#0; &#xD800; &bogus; &amp &lt &notit; &nbsp x</p></body></html>')
    add('h8-case.html', '<HTML><HEAD><TITLE>T</TITLE></HEAD><BODY><P CLASS=a ID=Q>A<BR>B<IMG SRC=x.png></P></BODY></HTML>')
    add('h9-nodoctype-text.html', 'leading text<p>a</p>trailing')
    add('i1-body-attrs.html', '<!DOCTYPE html><html lang="x"><body onload="x()" class="a"><p id="a" id="b">dup</p><script>var a = "<b>&amp;</b>";</script><style>p > a {}</style><textarea>\n<b>t</b></textarea><pre>\n\nx</pre></body></html>')
    add('i2-doctype-legacy.html', '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><html xmlns="http://www.w3.org/1999/xhtml"><head><title>t</title></head><body><p>q</p></body></html>')
    add('i3-frameset.html', '<!DOCTYPE html><html><head><title>t</title></head><frameset><frame src="a.html"></frameset></html>')
    add('i4-form-nest.html', h + '<form id="a"><p><form id="b"><input></form></p></form><table><form id="c"><tr><td>x</table></body></html>')
    add('i5-nested-formatting.html', h + '<p><b>1<i>2</b>3</i>4<a href="x">5<a href="y">6</a></a></p><h1>h<h2>i</h2></body></html>')
    add('i6-xml-in-html.xhtml', '<html><head><title>t</title></head><body><p>No namespace <svg><circle/></svg></p></body></html>', 'application/xhtml+xml')
    ncx = ('<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><navMap>'
           '<navPoint id="n1"><navLabel><text>One  Two</text></navLabel><content src="h1-noscript-body.html#a%20b"/>'
           '<navPoint id="n2"><navLabel><text>Sub</text></navLabel><content src="sub/../h2-noscript-head.html"/></navPoint></navPoint>'
           '<navPoint id="n3"><navLabel><text>Three</text></navLabel><content src="h3-template-body.html"/></navPoint></navMap></ncx>')
    items = ('<item id="css" href="s.css" media-type="text/css"/>'
             '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>')
    package('edge-html', secs, items, ncx=ncx)


def trim(source, name):
    data = json.loads(Path(source).read_text(encoding='utf-8'))
    keep = {
        'oracleSchemaVersion': data['oracleSchemaVersion'],
        'fixtureId': name,
        'provenance': {k: data['provenance'][k] for k in
                       ('engineName', 'engineVersion', 'referenceCommit', 'foliateCommit')},
        'package': data['package'],
        'resourceURLs': data['resourceURLs'],
        'sections': [{k: s[k] for k in ('href', 'cfiBase', 'parser', 'projection', 'canonical', 'samples')}
                     for s in data['sections']],
    }
    (OUT / f'{name}.webkit.json').write_text(
        json.dumps(keep, ensure_ascii=False, sort_keys=True, indent=1) + '\n', encoding='utf-8')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    if sys.argv[1] == 'build':
        build_xhtml()
        build_html()
    elif sys.argv[1] == 'trim':
        trim(sys.argv[2], sys.argv[3])
