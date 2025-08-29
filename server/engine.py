# server/engine.py
import os, hashlib, time, tempfile, subprocess
from typing import Optional, Tuple
from pydub import AudioSegment

# Optional imports guarded
def _lazy_import_coqui():
    from TTS.api import TTS as COQUI_TTS
    return COQUI_TTS

class TTSEngine:
    def __init__(self):
        self.engine = os.getenv("TTS_ENGINE", "coqui").lower()
        if self.engine not in ("coqui", "piper"):
            self.engine = "coqui"
        self.model_loaded = False
        self._tts = None
        self._model_name = os.getenv("COQUI_MODEL_NAME", "tts_models/en/vctk/vits")
        self._speaker_wav = os.getenv("COQUI_SPEAKER_WAV") or None
        self._piper_model = os.getenv("PIPER_MODEL_PATH") or None
        self._piper_phon = os.getenv("PIPER_PHONEME_PATH") or None

    def _load_model(self):
        if self.model_loaded:
            return
        if self.engine == "coqui":
            COQUI_TTS = _lazy_import_coqui()
            # Download & load model by name; CPU by default
            self._tts = COQUI_TTS(self._model_name)
        else:
            # Piper runs via CLI; ensure binary available
            if not self._piper_model:
                raise RuntimeError("PIPER_MODEL_PATH not set")
        self.model_loaded = True

    def synth(self, text: str, voice: Optional[str], speed: float = 1.0, fmt: str = "mp3") -> Tuple[str, bool, int]:
        """
        Returns (audio_path, cache_hit, elapsed_ms)
        """
        start = time.time()
        # basic cache key
        key = hashlib.sha1(f"{self.engine}|{self._model_name}|{self._piper_model}|{voice}|{speed}|{text}".encode("utf-8")).hexdigest()
        cache_dir = os.path.join(tempfile.gettempdir(), "odiadev_tts_cache")
        os.makedirs(cache_dir, exist_ok=True)
        out_wav = os.path.join(cache_dir, f"{key}.wav")
        out_final = os.path.join(cache_dir, f"{key}.{fmt}")

        if os.path.exists(out_final):
            elapsed = int((time.time() - start) * 1000)
            return out_final, True, elapsed

        self._load_model()

        if self.engine == "coqui":
            # Coqui returns wav file; speaker cloning if provided
            if self._speaker_wav and hasattr(self._tts, "tts_with_preset"):
                # Some models support speaker_wav directly; fallback to normal tts
                try:
                    self._tts.tts_to_file(text=text, file_path=out_wav, speaker_wav=self._speaker_wav, speed=speed)
                except TypeError:
                    self._tts.tts_to_file(text=text, file_path=out_wav, speed=speed)
            else:
                self._tts.tts_to_file(text=text, file_path=out_wav, speed=speed)

        else:
            # Piper CLI usage
            if not shutil.which("piper"):
                raise RuntimeError("piper binary not found in PATH")
            with open(out_wav, "wb") as f:
                proc = subprocess.Popen(["piper", "--model", self._piper_model, "--length_scale", str(1.0/speed)], stdin=subprocess.PIPE, stdout=f)
                proc.communicate(text.encode("utf-8"))
                if proc.returncode != 0:
                    raise RuntimeError("piper synthesis failed")

        # Convert to final format if needed
        if fmt == "wav":
            final_path = out_wav
        else:
            audio = AudioSegment.from_wav(out_wav)
            if fmt == "mp3":
                final_path = out_final
                audio.export(final_path, format="mp3")
            elif fmt == "ogg":
                final_path = out_final
                audio.export(final_path, format="ogg")
            else:
                final_path = out_wav  # default

        elapsed = int((time.time() - start) * 1000)
        return final_path, False, elapsed
