from pydantic import BaseModel

# Schema for Signing Up
class UserCreate(BaseModel):
    phone_number: str
    full_name: str
    password: str

# Schema for the Token Response
class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str

class RefreshTokenRequest(BaseModel):
    refresh_token: str