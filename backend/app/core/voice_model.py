# app/utils/voice_model.py
import torch
import torchaudio

if not hasattr(torchaudio, "list_audio_backends"):
    def _list_audio_backends():
        return ["soundfile"]
    torchaudio.list_audio_backends = _list_audio_backends
    
from speechbrain.inference import SpeakerRecognition
import numpy as np
import tempfile
import os
import soundfile as sf

# Singleton model holder
_MODEL = None

def load_model(device: str = "cpu", savedir: str = None):
    """
    Load the ECAPA-TDNN SpeechBrain SpeakerRecognition model.
    Call once at startup.
    device: 'cpu' or 'cuda'
    savedir: optional local cache path for the downloaded model
    """
    global _MODEL
    if _MODEL is not None:
        return _MODEL

    kwargs = {}
    if savedir:
        kwargs["savedir"] = savedir

    _MODEL = SpeakerRecognition.from_hparams(
        source="speechbrain/spkrec-ecapa-voxceleb",
        run_opts={"device": device},
        **kwargs
    )
    return _MODEL


def get_embedding_from_file(path: str):
    """
    Returns a normalized numpy embedding vector for the audio file at `path`.
    Compatible with SpeechBrain 1.x ECAPA-TDNN.
    """
    model = load_model()

    # Load audio
    waveform, sr = torchaudio.load(path)

    # Convert to mono if stereo
    if waveform.shape[0] > 1:
        waveform = waveform.mean(dim=0, keepdim=True)

    # Resample if needed
    if sr != 16000:
        waveform = torchaudio.functional.resample(waveform, sr, 16000)

    with torch.no_grad():
        embeddings = model.encode_batch(waveform)

    emb = embeddings.squeeze().cpu().numpy()

    # L2 normalization (CRITICAL for cosine similarity)
    emb = emb / (np.linalg.norm(emb) + 1e-10)

    return emb.astype(float)


def get_embedding_from_audio_array(audio_np: np.ndarray, sr: int = 16000):
    """
    Save audio array to a temporary .wav and call get_embedding_from_file.
    audio_np: 1D numpy array, float32 (assumed sampled at sr)
    """
    # ensure float32
    audio_np = audio_np.astype('float32')
    # write to temporary file
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_name = tmp.name
    try:
        sf.write(tmp_name, audio_np, sr, format='WAV')
        emb = get_embedding_from_file(tmp_name)
    finally:
        try:
            os.remove(tmp_name)
        except Exception:
            pass
    return emb


def cosine_similarity(a: np.ndarray, b: np.ndarray):
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    denom = (np.linalg.norm(a) * np.linalg.norm(b)) + 1e-10
    return float(np.dot(a, b) / denom)


def verify_embeddings(emb_ref: np.ndarray, emb_test: np.ndarray):
    """
    Compare two embeddings with cosine similarity; return similarity 0..1 (higher = more similar).
    """
    return cosine_similarity(emb_ref, emb_test)


def verify_files(file_ref: str, file_test: str):
    """
    Convenience wrapper using SpeechBrain's verify_files which returns (score, decision).
    score is a float (log-likelihood-ish / cosine depending on model); decision is boolean.
    We still recommend using embeddings + cosine similarity for more control.
    """
    model = load_model()
    score, decision = model.verify_files(file_ref, file_test)
    # If score is not in [-1..1], you may want to convert — but SpeechBrain's verify_files returns a similarity score
    return float(score), bool(decision)
