// Playback accepts only a current, actually translated, consent-authorized window.
export function liveSpeechWindow(value,target,remaining){
 if(!value||value.status!=="ready"||value.fallback!==false||value.uncertain!==false||target!=="en"||value.language!==target||value.source_language!=="fr"||typeof value.text!=="string"||!value.text.trim()||value.text.length>4000||!Number.isFinite(remaining)||remaining<=0||!Number.isInteger(value.start_ms)||!Number.isInteger(value.end_ms)||value.start_ms<0||value.end_ms<=value.start_ms||typeof value.recording_id!=="string"||! /^[a-f0-9-]{36}$/.test(value.recording_id))return null;
 return {key:value.recording_id+":"+value.start_ms+":"+value.end_ms+":"+target,text:value.text,ttl:Math.min(remaining,5000)};
}
export function listeningRate(value){return [0.75,1,1.25,1.5].includes(Number(value))?Number(value):1}
