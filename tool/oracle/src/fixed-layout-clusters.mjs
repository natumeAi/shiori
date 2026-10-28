import {readFileSync} from 'node:fs';
import path from 'node:path';
import {webkit} from 'playwright';
import {root} from './common.mjs';

// Measured ligature evidence, not a recovered shaper glyph buffer. Straight SVG
// replicas retain computed typography but remove positioning and textLength.
export async function measureClusters(corpus) {
  const browser=await webkit.launch({headless:true});
  try {
    const context=await browser.newContext({viewport:{width:320,height:240}});
    const font=readFileSync(path.join(root,corpus.font.path));
    await context.route('**/*',async route=>{
      const url=new URL(route.request().url());
      const fixture=corpus.cases.find(c=>url.pathname===`/${c.id}.xhtml`);
      const body=url.pathname==='/font.ttf'?font:fixture?.source??corpus.resources[url.pathname];
      if(body===undefined) return route.abort();
      const contentType=url.pathname.endsWith('.xhtml')?'application/xhtml+xml':
        url.pathname.endsWith('.css')?'text/css':url.pathname.endsWith('.ttf')?'font/ttf':'image/svg+xml';
      await route.fulfill({body,contentType});
    });
    const page=await context.newPage();
    const measure=async()=>page.evaluate(()=>{
      const nodes=[],walker=document.createTreeWalker(document.body??document.documentElement,NodeFilter.SHOW_TEXT);
      for(let n=walker.nextNode();n;n=walker.nextNode()) {
        if(n.parentElement.closest('style,defs')) continue;
        nodes.push(n);
      }
      return nodes.map((node,textNodeIndex)=>{
        const style=getComputedStyle(node.parentElement),ns='http://www.w3.org/2000/svg';
        const svg=document.createElementNS(ns,'svg'),el=document.createElementNS(ns,'text');
        svg.setAttribute('width','10000');svg.setAttribute('height','10000');
        svg.style.cssText='position:fixed;left:0;top:0;opacity:0;pointer-events:none';
        for(const key of ['font-family','font-size','font-style','font-weight','font-stretch',
          'font-kerning','font-feature-settings','letter-spacing','word-spacing','writing-mode',
          'text-orientation','direction','font-variant-ligatures']) el.style.setProperty(key,style.getPropertyValue(key));
        svg.append(el);document.documentElement.append(svg);
        const value=node.data;
        const graphemes=[...new Intl.Segmenter('en',{granularity:'grapheme'}).segment(value)]
          .map(({index,segment})=>[index,index+segment.length]);
        const inherited=style.fontVariantLigatures;
        const boundaries=ligatures=>{
          el.textContent=value;el.style.fontVariantLigatures=ligatures;
          return Array.from({length:value.length+1},(_,i)=>i?el.getSubStringLength(0,i):0);
        };
        const normal=boundaries(inherited),disabled=boundaries('none');
        const width=(text,ligatures)=>{
          el.textContent=text;el.style.fontVariantLigatures=ligatures;
          return el.getComputedTextLength();
        };
        // Minimal differing spans identify membership without guessing fi/fl.
        const spans=[];
        for(let length=2;length<=graphemes.length;length++) {
          for(let i=0;i+length<=graphemes.length;i++) {
            const start=graphemes[i][0],end=graphemes[i+length-1][1];
            if(spans.some(s=>s.range[0]>=start&&s.range[1]<=end)) continue;
            const text=value.slice(start,end),a=width(text,inherited),b=width(text,'none');
            if(Math.abs(a-b)>1e-6) spans.push({range:[start,end],normalAdvance:a,disabledAdvance:b});
          }
        }
        svg.remove();
        const ranges=graphemes.map(r=>[...r]);
        for(const {range:[start,end]} of spans) {
          const overlapping=ranges.filter(r=>r[0]<end&&r[1]>start);
          const a=Math.min(start,...overlapping.map(r=>r[0])),b=Math.max(end,...overlapping.map(r=>r[1]));
          ranges.splice(ranges.indexOf(overlapping[0]),overlapping.length,[a,b]);
        }
        const svgText=node.parentElement.closest('svg text');
        const foreign=node.parentElement.closest('foreignObject');
        return {kind:svgText?'svg-text':foreign?'foreign-object':'xhtml-text',textNodeIndex,
          ...(svgText?{svgTextIndex:[...document.querySelectorAll('svg text')].indexOf(svgText)}:{}),
          ...(!node.parentElement.getClientRects().length?{rendered:false}:{}),text:value,
          clusterMap:ranges,clusterSource:'webkit-measured-ligature-control',
          clusterConfirmation:'Measured graphemes plus minimal ligature-control spans; not a shaper glyph buffer',
          clusterEvidence:{method:'straight-SVG-computed-typography/getSubStringLength; minimal-substring/getComputedTextLength',
            control:'font-variant-ligatures:none',normalLigatures:inherited,
            boundaryUnit:'source-UTF16',normalBoundaryAdvances:normal,disabledBoundaryAdvances:disabled,
            ligatureSpans:spans}};
      });
    });
    for(const fixture of corpus.cases) {
      await page.goto(`http://fixture.invalid/${fixture.id}.xhtml`);
      await page.evaluate(()=>document.fonts.ready);
      const runs=await measure();
      if(runs.length) fixture.textRuns=runs;
    }
    await page.goto('about:blank');
    for(const probe of corpus.svgTextProbes) {
      await page.setContent(probe.source.replaceAll("url('/font.ttf')",`url(data:font/ttf;base64,${font.toString('base64')})`));
      await page.evaluate(()=>document.fonts.ready);
      const runs=await measure();
      if(runs.length!==1||runs[0].text!==probe.text) throw Error('Cluster probe source identity');
      const {kind,textNodeIndex,svgTextIndex,...provenance}=runs[0];
      Object.assign(probe,provenance);
    }
    corpus.clusterMeasurement={engine:'webkit',engineVersion:browser.version(),
      method:'computed-typography replicas; normal versus ligatures:none; all body text nodes'};
  } finally {await browser.close();}
}
