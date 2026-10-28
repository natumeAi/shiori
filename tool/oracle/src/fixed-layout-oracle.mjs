import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:http';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { webkit, chromium } from 'playwright';
import { unzlibSync } from 'fflate';
import { build } from 'esbuild';
import { corpus } from './fixed-layout-corpus.mjs';
import { measureSvgGraphics } from './fixed-layout-svg-graphics.mjs';
import { root, stableJSON, sha256, referenceCommit, foliateCommit } from './common.mjs';

function pixels(png) {
  const width = png.readUInt32BE(16), height = png.readUInt32BE(20);
  const depth = png[24], color = png[25];
  if (depth !== 8 || ![2, 6].includes(color) || png[28] !== 0) throw Error('PNG framing');
  const bpp = color === 6 ? 4 : 3, chunks = [];
  for (let i = 8; i < png.length;) {
    const n = png.readUInt32BE(i), tag = png.toString('ascii', i + 4, i + 8);
    if (tag === 'IDAT') chunks.push(png.subarray(i + 8, i + 8 + n));
    i += 12 + n;
  }
  const raw = unzlibSync(Buffer.concat(chunks)), rows = new Uint8Array(width * height * bpp);
  let k = 0;
  const paeth = (a, b, c) => {
    const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
    return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
  };
  for (let y = 0; y < height; y++) {
    const filter = raw[k++]; if (filter > 4) throw Error('PNG filter');
    for (let x = 0; x < width * bpp; x++) {
      const i = y * width * bpp + x, a = x >= bpp ? rows[i - bpp] : 0;
      const b = y ? rows[i - width * bpp] : 0, c = y && x >= bpp ? rows[i - width * bpp - bpp] : 0;
      rows[i] = (raw[k++] + [0, a, b, Math.floor((a + b) / 2), paeth(a, b, c)][filter]) & 255;
    }
  }
  return { at: (x, y) => [...rows.subarray((y * width + x) * bpp, (y * width + x) * bpp + 3),
    ...(bpp === 4 ? [rows[(y * width + x) * bpp + 3]] : [255])] };
}
async function referencePaint(page, png) {
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  const next=await page.screenshot({omitBackground:true});
  return {pngBase64:png.toString('base64'),paintStability:{
    twoAnimationFramesIdentical:png.equals(next),topLeft:pixels(png).at(0,0),
    ...(png.equals(next)?{}:{afterTwoFramesPNG:next.toString('base64')}),
  }};
}
const referenceDir = process.env.LAN_READER_DIR ?? 'D:/Projects/lan-reader';
const revision = execFileSync('git', ['-C', referenceDir, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
const dirty = execFileSync('git', ['-C', referenceDir, 'status', '--porcelain'], { encoding: 'utf8' }).trim();
if (revision !== referenceCommit || dirty) throw Error('Reference checkout must match clean pinned commit');
const packageJSON = JSON.parse(readFileSync(path.join(root, 'tool/oracle/package.json'), 'utf8'));
const fixedSource = readFileSync(path.join(root, 'tool/oracle/node_modules/foliate-js/fixed-layout.js'));
const font = readFileSync(path.join(root, corpus.font.path));
const fontFixtures = JSON.parse(readFileSync(path.join(root, 'test/fixtures/reader/fixed_layout/fonts.json'), 'utf8'));
const fontRoutes = new Map(fontFixtures.faces.map(f => [`/probe-font.${f.format}`, readFileSync(path.join(root, f.path))]));
const projectionBundle=(await build({stdin:{contents:"export {protectBookDocument} from '../reference/lan-reader-a4bda23/contentSecurity';export * as CFI from 'foliate-js/epubcfi.js';",resolveDir:path.join(root,'tool/oracle/src'),loader:'ts'},bundle:true,write:false,format:'iife',globalName:'A0Source',platform:'browser',target:'es2022'})).outputFiles[0].contents;
const server = createServer((req, res) => {
  if(req.url==='/projection.js'){res.setHeader('Content-Type','text/javascript');res.end(projectionBundle);return;}
  if (fontRoutes.has(req.url)) { res.setHeader('Content-Type', 'application/octet-stream'); res.end(fontRoutes.get(req.url)); return; }
  if (req.url === '/font.ttf') { res.setHeader('Content-Type', 'font/ttf'); res.end(font); return; }
  if (req.url === '/fixed-layout.js') { res.setHeader('Content-Type', 'text/javascript'); res.end(fixedSource); return; }
  if (corpus.resources[req.url]) {
    res.setHeader('Content-Type', req.url.endsWith('.css') ? 'text/css' : 'image/svg+xml');
    res.end(corpus.resources[req.url]); return;
  }
  const c = corpus.cases.find(c => `/${c.id}.xhtml` === req.url);
  if (c) { res.setHeader('Content-Type', 'application/xhtml+xml'); res.end(c.source); return; }
  res.setHeader('Content-Type', 'text/html'); res.end('<!doctype html><body style="margin:0"></body>');
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
const output = path.join(root, 'test/fixtures/reader/fixed_layout');
const publish=(file,value)=>{
  const json=stableJSON(value);
  if(process.argv.includes('--check')) {
    if(readFileSync(file,'utf8')!==json) throw Error(`Fixed oracle drift: ${file}`);
  } else writeFileSync(file,json);
};
const cross = path.join(root, 'build/fixed-layout-chromium');
mkdirSync(output, { recursive: true }); mkdirSync(cross, { recursive: true });
const results = {};
const sceneRows = ['cascade','box','paint','stacking','text','dimensions'];
const sceneStyleProperties = [
  'display','position','top','right','bottom','left','width','height',
  'min-width','max-width','min-height','max-height','box-sizing',
  'margin-top','margin-right','margin-bottom','margin-left',
  'padding-top','padding-right','padding-bottom','padding-left',
  'font-family','font-size','font-weight','font-style','line-height',
  'letter-spacing','word-spacing','white-space','text-align','text-indent',
  'color','background-color','background-image','background-repeat',
  'background-position','background-size','background-origin','background-clip',
  'border-top-width','border-right-width','border-bottom-width','border-left-width',
  'border-top-style','border-right-style','border-bottom-style','border-left-style',
  'border-top-color','border-right-color','border-bottom-color','border-left-color',
  'border-top-left-radius','border-top-right-radius','border-bottom-right-radius','border-bottom-left-radius',
  'opacity','visibility','z-index','transform','transform-origin','overflow-x','overflow-y',
];
try {
  for (const [name, type] of Object.entries({ webkit, chromium })) {
    const browser = await type.launch({ headless: true });
    try {
      const context = await browser.newContext({ viewport: { width: 320, height: 240 }, deviceScaleFactor: 1 });
      await context.route('**/*', r => r.request().url().startsWith(origin + '/') ? r.continue() : r.abort());
      const projectionPage=await context.newPage();await projectionPage.goto(origin);await projectionPage.addScriptTag({url:origin+'/projection.js'});
      const page = await context.newPage(), cases = [];
      await page.goto(origin);await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
      const controlPNG=await page.screenshot({omitBackground:true});
      const screenshotControl={description:'empty document before corpus',topLeft:pixels(controlPNG).at(0,0),pngBase64:controlPNG.toString('base64')};
      page.on('console', msg=>{if(msg.text().includes('font')||msg.text().includes('OTS'))console.log(`${name} ${msg.text()}`);});
      for (const c of corpus.cases) {
        await page.goto(`${origin}/${c.id}.xhtml`); await page.evaluate(() => document.fonts.ready);
        const geometry = await page.evaluate(({row,unsupportedDeclaration,textRuns=[],sceneStyleProperties}) => {
          const scene=['cascade','box','paint','stacking','text','dimensions'].includes(row);
          const box = r => [r.x, r.y, r.width, r.height];
          const baseline = node => {
            const method='zero-size-inline-block-baseline/getBoundingClientRect';
            // CSS2 10.8.1: an empty inline-block's baseline is its bottom
            // margin edge. CSSOM View returns its fractional element box;
            // no DOM Range rectangle is used to locate this baseline.
            // https://www.w3.org/TR/CSS22/visudet.html#leading
            // https://www.w3.org/TR/cssom-view/#dom-element-getboundingclientrect
            if(!node.parentElement.getClientRects().length) return {
              method,available:false,x:null,y:null,reason:'no-generated-layout-box',
            };
            // Only the new XHTML rows use viewport-normalized probe movement.
            // Keep the foreignObject measurement and its records unchanged.
            let translation='translateY(.375px)';
            if(scene) {
              const style=getComputedStyle(node.parentElement);
              if(style.visibility!=='visible') return {
                method,available:false,x:null,y:null,reason:'visibility-hidden',
              };
              let matrix=new DOMMatrix();
              for(let el=node.parentElement;el;el=el.parentElement) {
                const transform=getComputedStyle(el).transform;
                if(transform!=='none') matrix=new DOMMatrix(transform).multiply(matrix);
              }
              if(!matrix.is2D || matrix.a*matrix.d-matrix.b*matrix.c===0) return {
                method,available:false,x:null,y:null,reason:'noninvertible-or-3d-transform',
              };
              const inverse=matrix.inverse();
              translation=`translate(${inverse.c*.375}px,${inverse.d*.375}px)`;
            }
            const marker=document.createElementNS('http://www.w3.org/1999/xhtml','span');
            marker.style.cssText='display:inline-block;width:0;height:0;margin:0;padding:0;border:0;vertical-align:baseline;font-size:0;line-height:0';
            node.before(marker);
            try {
              const r=marker.getBoundingClientRect();
              marker.style.transform=translation;
              const delta=marker.getBoundingClientRect().y-r.y;
              if(Math.abs(delta-.375)>1e-6) throw Error('Baseline probe lost subpixel precision');
              return {method,available:true,x:r.x,y:r.y,coordinateSpace:'viewport-css-px',
                fractionalTranslationDeltaY:delta};
            } finally { marker.remove(); }
          };
          const elements = [...document.querySelectorAll('[data-source]')].map(el => ({
            id: el.id || null, role: el.getAttribute('data-source'), namespace: el.namespaceURI,
            box: box(el.getBoundingClientRect()), transform: getComputedStyle(el).transform,
            opacity: getComputedStyle(el).opacity, visibility: getComputedStyle(el).visibility,
            clipPath: getComputedStyle(el).clipPath.replaceAll(location.origin, ''),
            mask: getComputedStyle(el).maskImage.replaceAll(location.origin, ''),
            ...(scene ? {computedStyle:Object.fromEntries(sceneStyleProperties.map(property=>[
              property,getComputedStyle(el).getPropertyValue(property).replaceAll(location.origin,''),
            ]))} : {}),
          }));
          const texts = [], walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
          for (let node = walker.nextNode(); node; node = walker.nextNode()) {
            const clusters = [];
            for (let offset = 0; offset < node.length; offset++) {
              const range = document.createRange(); range.setStart(node, offset); range.setEnd(node, offset + 1);
              clusters.push({ utf16: offset, boxes: [...range.getClientRects()].map(box) });
            }
            const style=getComputedStyle(node.parentElement);
            const ctx=document.createElement('canvas').getContext('2d');
            ctx.font=style.font || `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
            ctx.fontKerning=style.fontKerning;
            ctx.letterSpacing=style.letterSpacing;ctx.wordSpacing=style.wordSpacing;
            const m=ctx.measureText(node.data);
            const advance={font:ctx.font,width:m.width,prefixWidths:Array.from({length:node.length+1},(_,i)=>ctx.measureText(node.data.slice(0,i)).width),
              actualAscent:m.actualBoundingBoxAscent,actualDescent:m.actualBoundingBoxDescent,
              fontAscent:m.fontBoundingBoxAscent,fontDescent:m.fontBoundingBoxDescent};
            const declared=textRuns.find(run=>run.textNodeIndex===texts.length);
            if(declared && declared.text!==node.data) throw Error('Fixture text-node identity drift');
            const textChannels = row==='text' ? {
              computedStyle:Object.fromEntries([...sceneStyleProperties,'vertical-align','text-decoration-line'].map(
                property=>[property,style.getPropertyValue(property).replaceAll(location.origin,'')])),
              // Measure every source boundary independently with the same
              // fractional baseline probe. Restore the original node after
              // each probe so the source/CFI walk remains byte-identical.
              boundaryBaselines:Array.from({length:node.length+1},(_,offset)=>{
                if(offset===0) return baseline(node);
                const tail=node.splitText(offset);
                try { return baseline(tail); }
                finally { node.appendData(tail.data);tail.remove(); }
              }),
            } : {};
            texts.push({ text: node.data, utf16Length: node.length, namespace: node.parentElement.namespaceURI, clusters, advance,
              ...textChannels,
              ...(declared ? {fixtureRun:declared} : {}),
              ...(scene || node.parentElement.closest('foreignObject') ? {baseline:baseline(node)} : {}),
            });
          }
          const svgTexts = [...document.querySelectorAll('svg text')].map((el,index) => {
            const measured={
            text: el.textContent, computedTextLength: el.getComputedTextLength(),
            characters: Array.from({ length: el.getNumberOfChars() }, (_, i) => {
              const p = el.getStartPositionOfChar(i), q = el.getEndPositionOfChar(i), r = el.getExtentOfChar(i);
              return { index: i, start: [p.x, p.y], end: [q.x, q.y], rotation: el.getRotationOfChar(i), extent: box(r) };
            }),
            };
            el.style.fontVariantLigatures='none';
            try { measured.ligatureControl={method:'getComputedTextLength/font-variant-ligatures:none',
              disabledLength:el.getComputedTextLength(),normalLength:measured.computedTextLength};
            } finally { el.style.removeProperty('font-variant-ligatures'); }
            return {...measured,fixtureRun:textRuns.find(run=>run.svgTextIndex===index)};
          });
          let dimensions, appliedDeclaration;
          if(row==='dimensions') {
            const el=document.querySelector('svg'),ctm=el.getScreenCTM();
            dimensions={viewport:document.querySelector('meta[name="viewport"]').content,
              rootWidth:el.getAttribute('width'),rootHeight:el.getAttribute('height'),
              lengthAPI:{method:'SVGLength.value',values:[el.width.baseVal.value,el.height.baseVal.value]},
              computedSize:[getComputedStyle(el).width,getComputedStyle(el).height],
              clientBox:box(el.getBoundingClientRect()),containingBox:box(document.body.getBoundingClientRect()),
              viewBox:[el.viewBox.baseVal.x,el.viewBox.baseVal.y,el.viewBox.baseVal.width,el.viewBox.baseVal.height],
              screenCTM:[ctm.a,ctm.b,ctm.c,ctm.d,ctm.e,ctm.f]};
          }
          if(unsupportedDeclaration) {
            const {selector,property,value}=unsupportedDeclaration,el=document.querySelector('#source');
            const rules=[...document.styleSheets].flatMap(sheet=>[...sheet.cssRules])
              .filter(rule=>rule.selectorText===selector);
            appliedDeclaration={...unsupportedDeclaration,elementMatches:el.matches(selector),
              matchingTopLevelRules:rules.filter(rule=>el.matches(rule.selectorText)).length,
              cssSupported:CSS.supports(property,value),
              retainedValues:rules.map(rule=>rule.style.getPropertyValue(property)),
              computedValue:getComputedStyle(el).getPropertyValue(property)};
            if(!appliedDeclaration.elementMatches || !appliedDeclaration.matchingTopLevelRules)
              throw Error('Outside-profile declaration rule does not apply');
          }
          return { elements, texts, svgTexts, fontLoaded: document.fonts.check('20px Fixture'),
            ...(scene ? {computedStyleProperties:sceneStyleProperties} : {}),
            ...(dimensions ? {dimensions} : {}),...(appliedDeclaration ? {appliedDeclaration} : {}) };
        }, {...c,sceneStyleProperties});
        const png = await page.screenshot({ omitBackground: true }), image = pixels(png);
        const paintReference=c.fallbackCharacters||c.variant!=='unsupported'&&['filters','clip-mask','svg-text','svg-graphics','foreign-object',...sceneRows].includes(c.row)
          ? await referencePaint(page,png) : {};
        const graphics = c.row === 'svg-graphics' ? await measureSvgGraphics(page) : null;
        const projectedTexts=await projectionPage.evaluate(source=>{
          const protectedSource=A0Source.protectBookDocument(source,'application/xhtml+xml');
          const doc=new DOMParser().parseFromString(protectedSource,'application/xhtml+xml');
          const walker=doc.createTreeWalker(doc.querySelector('body'),NodeFilter.SHOW_TEXT),texts=[];
          for(let node=walker.nextNode();node;node=walker.nextNode()){
            const cfis=Array.from({length:node.length+1},(_,offset)=>{const range=doc.createRange();range.setStart(node,offset);range.collapse(true);return {utf16:offset,cfi:A0Source.CFI.fromRange(range)};});
            texts.push({text:node.data,namespace:node.parentElement.namespaceURI,cfis});
          }
          return texts;
        },c.source);
        cases.push({ id: c.id, sourceSHA256: c.sha256, ...geometry, projectedTexts,
          ...(graphics ? {graphics} : {}),
          ...(c.fallbackCharacters?{fallbackCharacters:c.fallbackCharacters,
            geometryGate:c.geometryGate,pixelGate:c.pixelGate}:{}),
          samples: c.samplePoints.map(([x, y]) => ({ x, y, rgba: image.at(x, y) })),
          ...paintReference,
        });
      }
      await page.goto(origin);
      const navigation = await page.evaluate(async publications => {
        const { FixedLayout } = await import('/fixed-layout.js');
        return publications.map(p => {
          const view = new FixedLayout(), sections = p.sequence.map((s, index) => ({ index, pageSpread: s.side }));
          view.open({ dir: 'ltr', rendition: { spread: p.spread }, sections });
          return sections.map(s => ({ source: s.index, ...view.getSpreadOf(s) }));
        });
      }, corpus.cases.map(c => c.publication));
      const svgTextProbes=[];
      for(const probe of corpus.svgTextProbes){
        const {source}=probe;
        await page.setContent(source);await page.evaluate(()=>document.fonts.ready);
        const measurement=await page.evaluate(()=>{
          const el=document.querySelector('textPath');
          return {text:el.textContent,computedTextLength:el.getComputedTextLength(),
            characters:Array.from({length:el.getNumberOfChars()},(_,i)=>{
              const p=el.getStartPositionOfChar(i),q=el.getEndPositionOfChar(i),r=el.getExtentOfChar(i);
              return {index:i,start:[p.x,p.y],end:[q.x,q.y],rotation:el.getRotationOfChar(i),extent:[r.x,r.y,r.width,r.height]};
            })};
        });
        if(measurement.text!==probe.text) throw Error('Fixture probe identity drift');
        const png=await page.screenshot({omitBackground:true});
        svgTextProbes.push({...probe,...measurement,...await referencePaint(page,png)});
      }
      await page.goto(origin);
      const fontProbes = await page.evaluate(async faces => {
        const probes = [];
        for (const face of faces) {
          try {
            const family = `Probe${face.format}`;
            const font = new FontFace(family, await (await fetch(`/probe-font.${face.format}`)).arrayBuffer());
            await font.load(); document.fonts.add(font);
            document.body.innerHTML = `<div style="font:20px '${family}';width:max-content">Ab fi e\u0301 Z</div>`;
            const el = document.body.firstElementChild, node = el.firstChild, clusters = [];
            for (let offset = 0; offset < node.length; offset++) {
              const range = document.createRange(); range.setStart(node, offset); range.setEnd(node, offset + 1);
              clusters.push([...range.getClientRects()].map(b => [b.x, b.y, b.width, b.height]));
            }
            const ctx = document.createElement('canvas').getContext('2d'); ctx.font = `20px '${family}'`;
            const m = ctx.measureText(node.data);
            probes.push({ ...face, loaded: true, text: node.data, clusters, width: m.width,
              ascent: m.actualBoundingBoxAscent, descent: m.actualBoundingBoxDescent });
          } catch (error) { probes.push({ ...face, loaded: false, error: String(error) }); }
        }
        return probes;
      }, fontFixtures.faces);
      const result = { schemaVersion: 1, engine: name, engineVersion: browser.version(), fontProbes, svgTextProbes, screenshotControl,
        referenceCommit, referenceDirty: false, foliateCommit, fixedLayoutSHA256: sha256(fixedSource),
        nodeVersion: process.version, toolVersions: packageJSON.devDependencies,
        viewport: corpus.authoredSize, dpr: 1, font: corpus.font, corpusSHA256: sha256(stableJSON(corpus)),
        cases: cases.map((c, i) => ({ ...c, referenceSpreadSlots: navigation[i] })),
      };
      results[name] = result;
      publish(path.join(name === 'webkit' ? output : cross, 'oracle.json'), result);
      console.log(`${name} ${browser.version()}: ${cases.length} geometry/paint/source cases; font loads ${fontProbes.map(f => `${f.format}=${f.loaded}`).join(', ')}`);
    } finally { await browser.close(); }
  }
  const differences = [];
  for (let i = 0; i < corpus.cases.length; i++) {
    const a = results.webkit.cases[i], b = results.chromium.cases[i];
    if (stableJSON(a) !== stableJSON(b)) differences.push({ id: a.id,
      elementsIdentical: stableJSON(a.elements) === stableJSON(b.elements),
      textGeometryIdentical: stableJSON(a.texts) === stableJSON(b.texts),
      svgTextGeometryIdentical: stableJSON(a.svgTexts) === stableJSON(b.svgTexts),
      paintSamplesIdentical: stableJSON(a.samples) === stableJSON(b.samples),
      ...(a.pngBase64 ? { paintRasterIdentical: a.pngBase64 === b.pngBase64 } : {}),
    });
  }
  publish(path.join(output, 'cross-engine-differences.json'), { authoritative: 'webkit', differences,
    fontsIdentical: stableJSON(results.webkit.fontProbes) === stableJSON(results.chromium.fontProbes) });
} finally { server.close(); }
