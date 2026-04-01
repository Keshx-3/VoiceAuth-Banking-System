from app.core.database import SessionLocal, engine
# Explicitly import the User model here
from app.models.user import User  

# Create the session
db = SessionLocal()

print("Interactive Shell Started. 'db' session is ready.")