import {readFileSync,writeFileSync} from 'node:fs';
import {webkit,chromium} from 'playwright';
import {unzlibSync} from 'fflate';
import {root,stableJSON} from './common.mjs';
import path from 'node:path';
const font=readFileSync(path.join(root,'tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')).toString('base64');
const html=body=>`<html xmlns="http://www.w3.org/1999/xhtml"><head><style>@font-face{font-family:Fixture;src:url(data:font/ttf;base64,${font})}html,body{margin:0;width:320px;height:240px}body{font:20px Fixture}</style></head><body>${body}</body></html>`;
const svg=body=>`<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240" viewBox="0 0 320 240">${body}</svg>`;
const controls={empty:'',emptySVG:svg(''),rect:svg('<rect x="40" y="40" width="80" height="80" fill="red"/>'),
 foreignStatic:svg('<g transform="translate(10 15)"><foreignObject x="20" y="30" width="180" height="120"><div xmlns="http://www.w3.org/1999/xhtml" style="font:20px Fixture;color:red;border:2px solid blue;padding:4px">Ab fi<span> Z</span></div></foreignObject></g>'),
 foreignRelative:svg('<g transform="translate(10 15)"><foreignObject x="20" y="30" width="180" height="120"><div xmlns="http://www.w3.org/1999/xhtml" style="font:20px Fixture;color:red;border:2px solid blue;padding:4px">Ab fi<span style="position:relative;top:3px"> Z</span></div></foreignObject></g>')};
const firstPixel=png=>{const chunks=[];for(let i=8;i<png.length;){let n=png.readUInt32BE(i);if(png.toString('ascii',i+4,i+8)==='IDAT')chunks.push(png.subarray(i+8,i+8+n));i+=12+n;}return [...unzlibSync(Buffer.concat(chunks)).slice(1,5)];};
const measurements=[];
for(const [engine,type] of Object.entries({webkit,chromium})){
 const browser=await type.launch({headless:true});
 try{for(const [id,body] of Object.entries(controls)) for(const mediaType of ['text/html','application/xhtml+xml']){
  const context=await browser.newContext({viewport:{width:320,height:240},deviceScaleFactor:1});
  try{const page=await context.newPage();await page.goto(`data:${mediaType};base64,${Buffer.from(html(body)).toString('base64')}`);await page.evaluate(()=>document.fonts.ready);await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
   const png=await page.screenshot({omitBackground:true});measurements.push({engine,engineVersion:browser.version(),id,mediaType,isolatedContext:true,sourceBody:body,topLeft:firstPixel(png),pngBase64:png.toString('base64')});
  }finally{await context.close();}
 }}finally{await browser.close();}
}
const output=path.join(root,'test/fixtures/reader/fixed_layout/paint-controls.json');writeFileSync(output,stableJSON({schemaVersion:1,measurements}));
console.log(measurements.map(m=>`${m.engine} ${m.id} ${m.mediaType} ${m.topLeft}`).join('\n'));
