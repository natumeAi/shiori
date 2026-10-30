import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { root, stableJSON, sha256 } from './common.mjs';
import { measureClusters } from './fixed-layout-clusters.mjs';

const svg = (body, attrs = '') => `<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240" viewBox="0 0 320 240" ${attrs}>${body}</svg>`;
const text = '<div id="source" data-source="text">Ab fi é Z</div>';
const rows = [
  ['metadata', 'package/item layout; orientation; spread; left/right/center', text,
    'body{margin:0}', 'raw and effective rendition/source sequence must agree'],
  ['dimensions', 'viewport; viewBox origin; absolute SVG units; preserveAspectRatio; raster intrinsic',
    svg('<rect id="source" data-source="rect" x="20" y="30" width="40" height="50" fill="red"/>', 'preserveAspectRatio="xMidYMid meet"'), '',
    'finite positive dimensions; authored origin/aspect transform <=0.5 px'],
  ['cascade', 'selectors; cascade; inheritance; important; link/import/inline; screen/all; orientation/size queries',
    text, '#source{color:red!important} @media screen and (min-width:300px) and (orientation:landscape){#source{margin-left:12px}}',
    'all used declarations resolved; required ignored declarations fail'],
  ['box', 'block/inline/inline-block/none; static/relative/absolute/fixed; inset auto/length/percent; dimensions/min/max; margin/padding; sizing',
    `<div style="position:relative;width:200px;height:160px;padding:8px"><span style="display:none">excluded</span>${text}</div>`,
    '#source{position:absolute;left:10%;right:auto;top:12px;bottom:auto;min-width:40px;max-width:140px;width:50%;height:60px;margin:3px;padding:4px;box-sizing:border-box;display:inline-block}',
    'containing block, normal-flow descendants and box edges <=0.5 px; no cycles'],
  ['text', 'LTR; SFNT weight/style; size/line-height; spacing; align/indent; whitespace/wrap; decoration; sub/super',
    '<div id="source" data-source="text">Ab fi é Z<sub>2</sub><sup>3</sup><br/>next line</div>',
    '#source{font:italic 400 20px/28px Fixture;letter-spacing:1px;word-spacing:2px;text-align:left;text-indent:4px;white-space:pre-wrap;text-decoration:underline;width:150px}',
    'same font, UTF-16 clusters, baselines and wrapping; <=0.5 px'],
  ['paint', 'background color/image repeat/position/size; solid borders/radius; opacity; visibility descendants',
    `<div style="visibility:hidden">hidden<span style="visibility:visible">visible</span></div>${text}`,
    '#source{width:100px;height:80px;background:yellow url("/tile.svg") repeat 3px 4px/8px 8px;border:4px solid blue;border-radius:12px;opacity:.5;color:red}',
    'ordered visible paint; backgrounds cover boxes; opacity/hidden source not overcredited'],
  ['stacking', 'z-index auto/integer; opacity/transform contexts; matrix/translate/scale/rotate/skew; origin lengths/percent',
    '<div style="position:relative;opacity:.7"><div id="source" data-source="text">layer</div><div data-source="occluder" style="position:absolute;z-index:2;background:blue;width:10px;height:10px"></div></div>',
    '#source{position:absolute;z-index:-1;transform:matrix(1,0,0,1,2,3) translate(20px,10px) scale(1.1) rotate(10deg) skewX(5deg);transform-origin:25% 10px}',
    'paint order exact; transformed/inverse source boxes <=0.5 px; singular proof refuses'],
  ['clip-mask', 'overflow visible/hidden/clip; rectangle/path clip; group opacity; alpha/luminance mask',
    svg('<defs><clipPath id="clip"><circle cx="90" cy="90" r="60"/></clipPath><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="320" height="240" style="mask-type:luminance"><rect width="160" height="240" fill="#808080"/></mask></defs><g opacity=".5" clip-path="url(#clip)" mask="url(#m)"><rect id="source" data-source="rect" x="20" y="20" width="160" height="160" fill="red"/></g>'), '',
    'mask affects output and visibility; bounded layers; nested clip transforms <=0.5 px'],
  ['svg-graphics', 'g/defs/symbol/use; shapes/path; fill/stroke rules; gradient/pattern/marker/image; nested viewport',
    svg('<defs><linearGradient id="grad"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient><pattern id="pat" width="8" height="8" patternUnits="userSpaceOnUse"><rect width="4" height="8" fill="green"/></pattern><marker id="mark" markerWidth="3" markerHeight="3"><circle cx="1" cy="1" r="1"/></marker><symbol id="sym"><ellipse cx="10" cy="10" rx="8" ry="5"/></symbol></defs><g id="source" data-source="group" fill="url(#grad)" stroke="black" fill-rule="evenodd"><rect x="5" y="5" width="40" height="40"/><circle cx="70" cy="25" r="20"/><ellipse cx="120" cy="25" rx="20" ry="10"/><line x1="10" y1="70" x2="80" y2="70" marker-end="url(#mark)"/><polyline points="100,60 120,80 140,60"/><polygon points="160,60 180,80 200,60"/><path d="M10 100h80v60H10z M20 110v40h50v-40z"/><rect x="110" y="100" width="50" height="50" fill="url(#pat)"/><use href="#sym" x="180" y="100"/><svg x="220" y="100" width="50" height="50" viewBox="5 5 20 20"><image href="/tile.svg" width="20" height="20"/></svg></g>'), '',
    'all shapes/resources/references ordered and conserved; cycles/depth/ops bounded'],
  ['svg-text', 'text/tspan x/y/dx/dy/rotate; anchor; font; textPath/textLength/lengthAdjust',
    svg('<defs><path id="path" d="M20 100 Q160 10 290 120"/></defs><text id="source" data-source="text" x="160" y="40" text-anchor="middle" font-family="Fixture" font-size="20"><tspan dx="1 2" dy="0 1" rotate="0 10">Ab fi</tspan></text><text data-source="path-text" font-family="Fixture" font-size="20" textLength="180" lengthAdjust="spacingAndGlyphs"><textPath href="#path" startOffset="5%">Ab fi é Z</textPath></text>'), '',
    'per-cluster UTF-16 geometry and rotations exact; path length adjustment <=0.5 px'],
  ['foreign-object', 'static XHTML box/text/style; namespace/source; x/y/size; transform/clip; canonical SVG exclusion',
    svg('<g transform="translate(10 15)"><foreignObject id="source" data-source="foreign" x="20" y="30" width="180" height="120"><div xmlns="http://www.w3.org/1999/xhtml" data-source="text" style="font:20px Fixture;color:red;border:2px solid blue;padding:4px">Ab fi<span style="position:relative;top:3px"> Z</span></div></foreignObject></g>'), '',
    'XHTML rendered through native boxes; source ranges retained; canonical v1 stays excluded'],
  ['filters', 'Gaussian blur; offset; color matrix; flood; composite; blend; merge; units/region/color space',
    svg('<defs><filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="320" height="240" color-interpolation-filters="sRGB"><feGaussianBlur in="SourceGraphic" stdDeviation="3" result="blur"/><feOffset in="blur" dx="12" dy="8" result="off"/><feColorMatrix in="off" type="matrix" values="0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 1 0" result="green"/><feFlood flood-color="blue" flood-opacity=".5" result="flood"/><feComposite in="flood" in2="green" operator="in" result="comp"/><feBlend in="comp" in2="green" mode="screen" result="blend"/><feMerge><feMergeNode in="blend"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs><rect id="source" data-source="rect" x="40" y="40" width="80" height="80" fill="red" filter="url(#f)"/>'), '',
    'every primitive visibly consumed; region/edge/color-space match; no discarded filter output'],
  ['mixed-navigation', 'reflow/fixed/reflow; center/pair/blank; fragment/nonlinear; reverse; active source',
    '<div id="source" data-source="text">fragment target</div>', '',
    'source/spine order and CFI exact; blank has no source; no fixed/reflow pair'],
];
const font = readFileSync(path.join(root, 'tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf'));
const svgTextProbes = ['none','spacing','spacingAndGlyphs'].map(adjustment => ({
  adjustment, text:'Ab fi e\u0301 Z',
  source:`<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><defs><style>@font-face{font-family:Fixture;src:url('/font.ttf')}</style><path id="p" d="M20 100 Q160 10 290 120"/></defs><text font-family="Fixture" font-size="20"><textPath href="#p" startOffset="5%" ${adjustment==='none'?'':`textLength="180" lengthAdjust="${adjustment}"`}>Ab fi e\u0301 Z</textPath></text></svg>`,
}));
const cases = [];
for (const [row, features, body, css, criterion] of rows) {
  for (const variant of ['positive', 'boundary', 'nested', 'unsupported']) {
    const id = `${row}-${variant}`;
    const unsupported = variant === 'unsupported';
    let content = body;
    if(row==='svg-graphics' && variant==='boundary') {
      content=content.replace('id="grad"','id="grad" gradientUnits="userSpaceOnUse" x2="40" spreadMethod="reflect" gradientTransform="translate(5 0) scale(.7)"')
        .replace('id="pat"','id="pat" patternTransform="translate(2 3)"')
        .replace('id="mark"','id="mark" orient="auto-start-reverse"');
      content=content.replace('</g></svg>',
        '<defs><radialGradient id="rad" gradientUnits="objectBoundingBox" spreadMethod="repeat" gradientTransform="rotate(10 .5 .5)" cx=".5" cy=".5" r=".4" fx=".4" fy=".4"><stop stop-color="yellow"/><stop offset="1" stop-color="blue"/></radialGradient></defs>'+
        '<path d="M10 180l10-5H40h5V185v5C45 200 40 210 35 205c-5 0-5 5-10 5S10 215 10 210s-5-5-5-10Q5 190 10 190q5 0 5-5T20 180t5 0A5 8 30 0 1 35 185a5 5 0 1 0 5 5Z m1e1 1e1 5 0 0 5z" fill="none" stroke="black" stroke-width="2" stroke-linecap="round" stroke-linejoin="bevel" stroke-miterlimit="3" stroke-dasharray="2 1 3" stroke-dashoffset="1"/>'+
        '<rect x="110" y="170" width="50" height="50" fill="url(#rad)"/>'+
        '<polyline points="180,180 200,190 220,180 230,200" fill="none" marker-start="url(#mark)" marker-mid="url(#mark)" marker-end="url(#mark)"/>'+
        '</g></svg>');
    }
    let extra = '';
    if (variant === 'nested') content = `<div data-source="outer" style="position:relative;transform:translate(7px,9px);opacity:.8;overflow:hidden;width:300px;height:220px">${body}</div>`;
    if(row==='svg-graphics' && variant==='nested') content=content.replace('</g></svg>',
      '<svg x="240" y="180" width="40" height="30" viewBox="5 5 20 10" preserveAspectRatio="none"><rect x="5" y="5" width="20" height="10" fill="blue"/></svg></g></svg>');
    if (variant === 'boundary') {
      extra = ({
        metadata:'', dimensions:'',
        cascade:'@media (max-width:320px){#source{padding-left:3px!important}}',
        box:'#source{min-width:140px;max-width:40px;left:auto;right:0;top:auto;bottom:0;width:50%;height:0;box-sizing:content-box}',
        text:'#source{white-space:nowrap;width:30px;text-align:justify;line-height:1;vertical-align:baseline}',
        paint:'#source{opacity:0;visibility:hidden}#source span{visibility:visible}',
        stacking:'#source{transform:matrix(0,0,0,1,0,0)}',
        'clip-mask':'svg{overflow:clip}',
        'svg-graphics':'svg{overflow:hidden}',
        'svg-text':'svg{font-kerning:none}',
        'foreign-object':'svg{overflow:hidden}', filters:'', 'mixed-navigation':'',
      })[row];
    }
    if (unsupported) extra = ({
      metadata:'', dimensions:'',
      cascade:'#source[data-source="text"]{future-layout:active}',
      box:'#source{display:grid}', text:'#source{writing-mode:vertical-rl}',
      paint:'#source{background:conic-gradient(red,blue)}',
      stacking:'#source{transform:rotateY(45deg)}',
      'clip-mask':'#source{clip-path:ray(45deg)}',
      'svg-graphics':'#source{filter:url(#unknown)}',
      'svg-text':'#source{writing-mode:vertical-rl}',
      'foreign-object':'#source{transform:perspective(20px)}',
      filters:'#source{filter:url(#unknown)}',
      'mixed-navigation':'body{direction:rtl}',
    })[row];
    if(row==='clip-mask' && variant==='boundary') content=content.replace('mask-type:luminance','mask-type:alpha');
    if(row==='filters' && variant==='boundary') content=content.replace('color-interpolation-filters="sRGB"','color-interpolation-filters="linearRGB"').replace('stdDeviation="3"','stdDeviation="0"');
    if(row==='filters' && variant==='nested') content=content.replace('color-interpolation-filters="sRGB"','color-interpolation-filters="linearRGB"');
    if(row==='dimensions' && variant==='nested') content=content.replace('viewBox="0 0 320 240"','viewBox="20 30 320 240"').replace('xMidYMid meet','xMinYMax slice');
    // Keep the valid containing-block SVG sizes; the unsupported page viewport
    // below is device-relative rather than EPUB's authored CSS-pixel size.
    if(row==='dimensions' && unsupported) content=content.replace('width="320" height="240"','width="50%" height="75%"');
    if(row==='box' && variant==='positive') content+='<div data-source="fixed-box" style="position:fixed;right:2px;bottom:2px;display:block;padding:1px"><span style="position:relative;left:2px;display:inline">nested flow</span></div>';
    // Existing row/variant, dedicated to platform fallback. Host evidence only
    // establishes paint/source conservation; same-font geometry/pixels wait A5.
    const fallbackCharacters=row==='text'&&variant==='boundary'
      ? [{codePoint:'U+1F600',textNodeIndex:0,utf16:[0,2]}] : null;
    if(fallbackCharacters) {
      content='<div id="source" data-source="text">\u{1f600}</div>';
      extra+='#source{font:20px Fixture;letter-spacing:normal;word-spacing:normal;text-decoration:none;text-indent:0;white-space:nowrap}';
    }
    if(row==='filters' && unsupported) content=content.replace('<feGaussianBlur','<feTurbulence baseFrequency=".05"/><feGaussianBlur');
    if(row==='foreign-object' && unsupported) content=content.replace('</div>','<script>throw new Error("must never execute")</script><form><input value="inert"/></form></div>');
    const viewport = row === 'dimensions' && unsupported ? 'width=device-width,height=240'
      : row === 'dimensions' && variant === 'boundary' ? 'width=0,height=NaN' : 'width=320,height=240';
    const source = `<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head><meta name="viewport" content="${viewport}"/><link rel="stylesheet" href="/linked.css"/><style>@import url('/imported.css');@font-face{font-family:Fixture;src:url('/font.ttf') format('truetype')}html,body{margin:0;width:320px;height:240px}body{font:20px Fixture}${css}${extra}</style></head><body>${content}</body></html>\n`;
    const sequence = row === 'mixed-navigation' ? [
      {layout:'reflowable', linear:true}, {layout:'pre-paginated',side:'center',linear:true},
      {layout:'pre-paginated',side:'left',linear:true}, {layout:'pre-paginated',side:'right',linear:true},
      {layout:'pre-paginated',side:'center',linear:false}, {layout:'reflowable',linear:true},
    ] : [{layout:'pre-paginated',side:variant === 'boundary'?'center':'right',linear:true}];
    const packageLayout=row==='metadata'&&variant==='boundary'?'reflowable':row==='metadata'&&unsupported?'future-layout':'pre-paginated';
    const orientation=unsupported&&row==='metadata'?'diagonal':['auto','portrait','landscape','auto'][cases.length%4];
    const spread=unsupported&&row==='metadata'?'future-spread':['auto','none','landscape','both'][cases.length%4];
    const packageSource=`<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="uid">synthetic-a0-${id}</dc:identifier><dc:title>A0 synthetic</dc:title><dc:language>en</dc:language><meta property="rendition:layout">${packageLayout}</meta><meta property="rendition:orientation">${orientation}</meta><meta property="rendition:spread">${spread}</meta></metadata><manifest>${sequence.map((s,i)=>`<item id="p${i}" href="p${i}.xhtml" media-type="application/xhtml+xml"/>`).join('')}</manifest><spine page-progression-direction="${unsupported&&row==='mixed-navigation'?'rtl':'ltr'}">${sequence.map((s,i)=>`<itemref idref="p${i}" linear="${s.linear?'yes':'no'}" properties="rendition:layout-${s.layout}${s.side?' page-spread-'+s.side:''}"/>`).join('')}</spine></package>`;
    cases.push({id,row,variant,features,criterion,
      expectedCapability:unsupported?'unsupported':row==='dimensions'&&variant==='boundary'?'malformed':'required',
      publication:{layout:packageLayout,orientation,spread,sequence,packageSource},
      source,sha256:sha256(source),samplePoints:[[60,60],[132,100],[170,90],[10,10]],
      ...(fallbackCharacters ? {fallbackCharacters,geometryGate:'device-gated (A5)',pixelGate:'device-gated (A5)'} : {}),
      ...(row==='cascade' && unsupported ? {unsupportedDeclaration:{
        selector:'#source[data-source="text"]',property:'future-layout',value:'active',
      }} : {}),
    });
  }
}
if(cases.length!==52 || new Set(cases.map(c=>c.row)).size!==13)throw Error('Capability row coverage');
export const corpus = {schemaVersion:1,authoredSize:[320,240],geometryToleranceCssPx:.5,
  font:{sha256:sha256(font),bytes:font.length,format:'sfnt',path:'tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf'},
  resources:{'/linked.css':'[data-source]{box-sizing:content-box}', '/imported.css':'@media all{body{direction:ltr}}',
    '/tile.svg':svg('<rect width="4" height="8" fill="cyan"/>')},cases,svgTextProbes};
await measureClusters(corpus);
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname.replace(/^\/(\w:)/,'$1'))) {
  const output=path.join(root,'test/fixtures/reader/fixed_layout/corpus.json');
  const json=stableJSON(corpus);
  if(process.argv.includes('--check')) {
    if(readFileSync(output,'utf8')!==json) throw new Error('Fixed corpus drift; regenerate');
  } else { mkdirSync(path.dirname(output),{recursive:true});writeFileSync(output,json); }
  console.log(`Fixed capability corpus: ${rows.length} rows / ${cases.length} cases; ${sha256(json)}`);
}
