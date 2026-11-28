import test from "node:test";
import assert from "node:assert/strict";
import {validMediaBytes,safeMediaName,mediaDigest,encodeMedia,decodeMedia,MAX_CHAT_MEDIA_BYTES} from "./chat-media.mjs";
const bytes=s=>new TextEncoder().encode(s);
test("B2 chat media accepts allowed file and voice signatures only",()=>{
 assert.equal(validMediaBytes("file","application/pdf",bytes("%PDF-1.4 test")),true);
 assert.equal(validMediaBytes("voice","audio/ogg",bytes("OggS test")),true);
 assert.equal(validMediaBytes("file","audio/ogg",bytes("OggS test")),false);
 assert.equal(validMediaBytes("voice","audio/ogg",bytes("<html>test</html>")),false);
 assert.equal(validMediaBytes("file","image/svg+xml",bytes("<svg>test</svg>")),false);
 assert.equal(validMediaBytes("file","application/pdf",new Uint8Array(MAX_CHAT_MEDIA_BYTES+1)),false);
});
test("B2 canonical media payload, name and digest",async()=>{
 const b=bytes("%PDF-1.4 fixture"),encoded=encodeMedia(b);
 assert.deepEqual(decodeMedia(encoded),b);assert.throws(()=>decodeMedia("YQ"));
 assert.throws(()=>decodeMedia("YQ==\n"));
 assert.equal(await mediaDigest(bytes("abc")),"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
 assert.equal(safeMediaName("../<script>.html","application/pdf").endsWith(".pdf"),true);
 assert.equal(safeMediaName("../<script>.html","application/pdf").includes("/"),false);
 assert.throws(()=>safeMediaName("test","text/html"));
});
