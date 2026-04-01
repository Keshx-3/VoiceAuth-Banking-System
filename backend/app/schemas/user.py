from pydantic import BaseModel, field_validator
from typing import Optional
from app.core.config import settings

class UserBase(BaseModel):
    phone_number: str
    full_name: str

class UserResponse(UserBase):
    id: int
    balance: float
    is_active: bool
    use_voice_auth: bool
    profile_pic: Optional[str] = None

    # --- THE MAGIC VALIDATOR ---
    @field_validator("profile_pic")
    @classmethod
    def make_url_absolute(cls, v):
        if v:
            # Check if it already has http (in case we accidentally save it twice)
            if v.startswith("http"):
                return v
            # Prepend the domain from settings
            return f"{settings.BASE_URL}/{v}"
        return v
    # ---------------------------

    class Config:
        from_attributes = True  # Crucial for reading SQLAlchemy models

class UserContact(BaseModel):
    id: int  
    phone_number: str
    full_name: str
    profile_pic: Optional[str] = None
    
    @field_validator("profile_pic")
    @classmethod
    def make_url_absolute(cls, v):
        from app.core.config import settings
        if v and not v.startswith("http"):
            return f"{settings.BASE_URL}/{v}"
        return v

    class Config:
        from_attributes = True