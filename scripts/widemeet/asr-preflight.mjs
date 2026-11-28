// Real local inference on synthetic speech; no account, meeting data, or cloud credentials.
import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {mkdtemp,rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {runLocalAsr,localAsrFailure} from "../../packages/media-core/widemeet-transcription.mjs";
const dir=await mkdtemp(join(tmpdir(),"wm-asr-preflight-"));
try{
 const wav=join(dir,"synthetic.wav"),ogg=join(dir,"synthetic.ogg");
 execFileSync("espeak-ng",["-v","en-us","-s","125","-w",wav,"Today we discuss the project. The meeting is about the project. Thank you for attending the meeting."]);
 execFileSync("ffmpeg",["-v","error","-y","-i",wav,"-c:a","libopus",ogg]);
 let result;
 try{result=await runLocalAsr({python:process.env.WM_ASR_PYTHON,modelDir:process.env.WM_ASR_MODEL,path:ogg,home:dir})}
 catch(e){throw Error("Local ASR preflight: "+localAsrFailure(e))}
 assert.equal(result.model,"whisper-tiny-local");assert.equal(result.language,"en");
 assert.ok(result.segments.length>0&&result.duration_ms>0);
 assert.match(result.segments.map(x=>x.text).join(" "),/project|meeting/i);
 for(const s of result.segments)assert.ok(s.end_ms>s.start_ms&&s.start_ms>=0&&s.end_ms<=result.duration_ms+1000&&typeof s.uncertain==="boolean");
 console.log("PASS real isolated offline ASR preflight with identical worker environment");
}finally{await rm(dir,{recursive:true,force:true})}
