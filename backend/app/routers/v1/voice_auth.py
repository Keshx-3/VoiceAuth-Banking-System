import json
import tempfile
import numpy as np

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.voice_embedding import VoiceProfile

from app.core.audio_utils import load_audio
from app.core.voice_model import get_embedding_from_audio_array
from app.core.similarity import cosine_similarity


router = APIRouter(prefix="/voice", tags=["Voice Authentication"])

@router.post("/register")
async def register_voice(
    audio_files: list[UploadFile] = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if len(audio_files) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least 2 voice samples required"
        )

    embeddings: list[list[float]] = []

    for audio in audio_files:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp:
            temp.write(await audio.read())
            file_path = temp.name

        audio_arr = load_audio(file_path)
        emb = get_embedding_from_audio_array(audio_arr, sr=16000)

        embeddings.append(emb.tolist())  # ✅ JSON safe

    # -------------------------------
    # Dynamic Threshold Calculation
    # -------------------------------
    internal_sims = []
    for i in range(len(embeddings)):
        for j in range(i + 1, len(embeddings)):
            sim = cosine_similarity(
                np.array(embeddings[i]),
                np.array(embeddings[j])
            )
            internal_sims.append(sim)

    threshold = max(min(internal_sims) - 0.05, 0.60) if internal_sims else 0.75

    # -------------------------------
    # Upsert Voice Profile
    # -------------------------------
    profile = db.query(VoiceProfile).filter_by(user_id=current_user.id).first()

    payload = json.dumps({
        "embeddings": embeddings,
        "threshold": threshold
    })

    if profile:
        profile.embedding = payload
    else:
        profile = VoiceProfile(
            user_id=current_user.id,
            embedding=payload
        )
        db.add(profile)

    db.commit()

    return {
        "message": "Voice registered successfully",
        "user_id": current_user.id
    }


@router.post("/verify")
async def verify_voice(
    audio: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    profile = db.query(VoiceProfile).filter_by(user_id=current_user.id).first()

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Voice not registered"
        )

    data = json.loads(profile.embedding)
    stored_embeddings = data["embeddings"]
    threshold = data["threshold"]

    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp:
        temp.write(await audio.read())
        file_path = temp.name

    audio_arr = load_audio(file_path)
    new_emb = get_embedding_from_audio_array(audio_arr, sr=16000)

    similarities = [
        cosine_similarity(np.array(emb), new_emb)
        for emb in stored_embeddings
    ]

    best_similarity = max(similarities)
    authenticated = best_similarity >= threshold

    return {
        "similarity": float(best_similarity),
        "authenticated": authenticated
    }
