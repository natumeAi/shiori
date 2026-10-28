import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {brotliCompressSync} from 'node:zlib';
import path from 'node:path';
import {root,sha256,stableJSON} from './common.mjs';
// The fixtures preserve every SFNT table. WOFF1 permits uncompressed tables;
// WOFF2 uses the specified null transform (version 3 for glyf/loca, 0 otherwise),
// arbitrary 4-byte tags, and one Brotli stream. No third-party encoder needed.
// https://www.w3.org/TR/WOFF2/#table_dir_format
const inputPath='tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf';
const sfnt=readFileSync(path.join(root,inputPath));
const n=sfnt.readUInt16BE(4), align=n=>(n+3)&~3;
const tables=Array.from({length:n},(_,i)=>{const o=12+16*i,offset=sfnt.readUInt32BE(o+8),length=sfnt.readUInt32BE(o+12);
 return {tag:sfnt.toString('ascii',o,o+4),checksum:sfnt.readUInt32BE(o+4),length,data:sfnt.subarray(offset,offset+length)};});
const sfntSize=12+16*n+tables.reduce((s,t)=>s+align(t.length),0);
const woff=Buffer.alloc(44+20*n+tables.reduce((s,t)=>s+align(t.length),0));
woff.write('wOFF');sfnt.copy(woff,4,0,4);woff.writeUInt32BE(woff.length,8);woff.writeUInt16BE(n,12);woff.writeUInt32BE(sfntSize,16);woff.writeUInt16BE(1,20);
let offset=44+20*n;
for(const [i,t] of tables.entries()){const o=44+20*i;woff.write(t.tag,o);woff.writeUInt32BE(offset,o+4);woff.writeUInt32BE(t.length,o+8);woff.writeUInt32BE(t.length,o+12);woff.writeUInt32BE(t.checksum,o+16);t.data.copy(woff,offset);offset+=align(t.length);}
const base128=n=>{const bytes=[n&127];while((n=Math.floor(n/128))>0)bytes.unshift((n&127)|128);return Buffer.from(bytes);};
const tags=['cmap','head','hhea','hmtx','maxp','name','OS/2','post','cvt ','fpgm','glyf','loca','prep','CFF ','VORG','EBDT','EBLC','gasp','hdmx','kern','LTSH','PCLT','VDMX','vhea','vmtx','BASE','GDEF','GPOS','GSUB','EBSC','JSTF','MATH','CBDT','CBLC','COLR','CPAL','SVG ','sbix','acnt','avar','bdat','bloc','bsln','cvar','fdsc','feat','fmtx','fvar','gvar','hsty','just','lcar','mort','morx','opbd','prop','trak','Zapf','Silf','Glat','Gloc','Feat','Sill'];
// WOFF2 requires the glyf/loca table data to be adjacent even without transforms.
const ordered=[...tables].sort((a,b)=>a.tag==='loca'?-1:b.tag==='loca'?1:0);
const glyf=ordered.findIndex(t=>t.tag==='glyf');const loca=ordered.shift();ordered.splice(glyf,0,loca);
const dir=Buffer.concat(ordered.flatMap(t=>{const index=tags.indexOf(t.tag);return [Buffer.from([(index<0?63:index)|(['glyf','loca'].includes(t.tag)?192:0)]),...(index<0?[Buffer.from(t.tag)]:[]),base128(t.length)];}));
const compressed=brotliCompressSync(Buffer.concat(ordered.map(t=>t.data)));
const header=Buffer.alloc(48);header.write('wOF2');sfnt.copy(header,4,0,4);header.writeUInt32BE(48+dir.length+compressed.length,8);header.writeUInt16BE(n,12);header.writeUInt32BE(sfntSize,16);header.writeUInt32BE(compressed.length,20);header.writeUInt16BE(1,24);
const output='test/fixtures/reader/fixed_layout';mkdirSync(path.join(root,output),{recursive:true});
const faces=[{format:'sfnt',path:inputPath,sha256:sha256(sfnt),bytes:sfnt.length}];
for(const [format,bytes] of [['woff',woff],['woff2',Buffer.concat([header,dir,compressed])]]){
 const file=`${output}/Roboto-Regular.${format}`;writeFileSync(path.join(root,file),bytes);faces.push({format,path:file,sha256:sha256(bytes),bytes:bytes.length});}
writeFileSync(path.join(root,output,'fonts.json'),stableJSON({schemaVersion:1,sameSourceTables:true,source:inputPath,faces}));
console.log(faces.map(f=>`${f.format}: ${f.bytes} bytes`).join('\n'));
