// Real local inference with isolated synthetic bilingual speech and silence; no client audio.
import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {mkdtemp,rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {runLocalAsr,localAsrFailure} from "../../packages/media-core/widemeet-transcription.mjs";
const dir=await mkdtemp(join(tmpdir(),"wm-asr-preflight-"));
async function infer(path){
 try{return await runLocalAsr({python:process.env.WM_ASR_PYTHON,modelDir:process.env.WM_ASR_MODEL,path,home:dir})}
 catch(e){throw Error("Local ASR preflight: "+localAsrFailure(e))}
}
try{
 for(const fixture of [
  {lang:"en",voice:"en-us",text:"Today we discuss the project. The meeting is about the project. Thank you for attending the meeting.",expected:/project|meeting/i},
  {lang:"fr",voice:"fr",text:"Bonjour. Nous parlons du projet. La réunion commence maintenant. Merci de votre participation à cette réunion.",expected:/projet|réunion/i}
 ]){
  const wav=join(dir,fixture.lang+".wav"),ogg=join(dir,fixture.lang+".ogg");
  execFileSync("espeak-ng",["-v",fixture.voice,"-s","125","-w",wav,fixture.text]);
  execFileSync("ffmpeg",["-v","error","-y","-i",wav,"-c:a","libopus",ogg]);
  const result=await infer(ogg);
  assert.equal(result.model,"whisper-tiny-local");assert.equal(result.language,fixture.lang);
  assert.ok(result.segments.length>0&&result.duration_ms>0);
  assert.match(result.segments.map(x=>x.text).join(" "),fixture.expected);
  for(const s of result.segments)assert.ok(s.end_ms>s.start_ms&&s.start_ms>=0&&s.end_ms<=result.duration_ms+1000&&typeof s.uncertain==="boolean");
  console.log("PASS real isolated offline ASR preflight "+fixture.lang+" with identical worker environment");
 }
 const silence=join(dir,"silence.ogg");
 execFileSync("ffmpeg",["-v","error","-y","-f","lavfi","-i","anullsrc=r=16000:cl=mono","-t","4","-c:a","libopus",silence]);
 const quiet=await infer(silence);
 assert.equal(quiet.segments.length,0,"silence must not generate text");
 console.log("PASS offline ASR silent input emits no transcript");
 const translated=await runLocalAsr({python:process.env.WM_ASR_PYTHON,modelDir:process.env.WM_ASR_MODEL,path:join(dir,"fr.ogg"),home:dir,translate:true});
 assert.equal(translated.language,"fr");assert.match(translated.segments.map(x=>x.text).join(" "),/project|meeting/i);
 console.log("PASS actual local Whisper French speech to English text");

}finally{await rm(dir,{recursive:true,force:true})}
