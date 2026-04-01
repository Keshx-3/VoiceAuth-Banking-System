import librosa
import numpy as np

SR = 16000  # recommended for resemblyzer


def load_audio(file_path):
    audio, sr = librosa.load(file_path, sr=SR)
    audio = audio.astype(np.float32)

    # Step 1: Trim silence
    audio, _ = librosa.effects.trim(audio, top_db=25)

    # Step 2: Normalize volume
    if np.max(np.abs(audio)) > 0:
        audio = audio / np.max(np.abs(audio))

    # Step 3: Reduce background noise
    # audio = nr.reduce_noise(y=audio, sr=SR)

    # Step 4: Standardize length (max 3 seconds)
    max_len = SR * 3
    if len(audio) > max_len:
        audio = audio[:max_len]

    return audio
