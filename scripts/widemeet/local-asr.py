"""Local ASR only. Model files must already exist; no remote inference."""
import json, os, sys
from pathlib import Path
from faster_whisper import WhisperModel
def main():
    if len(sys.argv) != 3:
        raise ValueError("local model and audio required")
    model_path, audio_path = map(Path, sys.argv[1:])
    if not model_path.is_dir() or not audio_path.is_file():
        raise ValueError("local input missing")
    model = WhisperModel(str(model_path), device="cpu", compute_type="int8", cpu_threads=2, local_files_only=True)
    segments, info = model.transcribe(str(audio_path), beam_size=3, vad_filter=True, condition_on_previous_text=False)
    duration = round(info.duration * 1000)
    if not 1 <= duration <= 7200000:
        raise ValueError("audio duration unsupported")
    result = []
    for s in segments:
        text = s.text.strip()
        if not text:
            continue
        if len(text) > 2000 or len(result) >= 1000:
            raise ValueError("transcript limit")
        start, end = round(s.start * 1000), round(s.end * 1000)
        if end <= start:
            continue
        result.append({"start_ms":start,"end_ms":end,"text":text,"uncertain":bool(s.avg_logprob < -0.7 or s.no_speech_prob > 0.3 or info.language_probability < 0.8)})
    print(json.dumps({"model":"whisper-tiny-local","language":info.language,"duration_ms":duration,"segments":result},ensure_ascii=False))
if __name__ == "__main__":
    main()
