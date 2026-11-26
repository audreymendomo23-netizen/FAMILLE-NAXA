import test from "node:test";import assert from "node:assert/strict";
function lum(hex){const xs=hex.match(/.{2}/g).map(x=>parseInt(x,16)/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4);return .2126*xs[0]+.7152*xs[1]+.0722*xs[2]}
for(const [fg,bg] of [["121714","78C800"],["121714","FFE52B"],["121714","29B9FF"],["121714","FF9A24"],["FFFFFF","07552C"],["F8FAF7","101611"],["F8FAF7","1A241C"],["121714","F6FAEF"]])test("contrast "+fg+"/"+bg,()=>{const a=lum(fg),b=lum(bg);assert.ok((Math.max(a,b)+.05)/(Math.min(a,b)+.05)>=4.5)});
