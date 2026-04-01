import time
import uuid
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from app.core.logger import logger

class LogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # 1. Generate a unique ID for this request (shortened for readability)
        request_id = str(uuid.uuid4())[:8] 
        
        # 2. Bind this ID to the logger context
        # All logs inside this 'with' block will automatically have this request_id
        with logger.contextualize(request_id=request_id):
            start_time = time.time()
            
            # Log Start
            logger.info(f"➡️  Incoming: {request.method} {request.url.path}")
            
            try:
                # Process the request
                response = await call_next(request)
                
                # Calculate time taken
                process_time = (time.time() - start_time) * 1000
                
                # Log Success
                logger.info(
                    f"✅ Completed: {response.status_code} | Took: {process_time:.2f}ms"
                )
                
                return response
                
            except Exception as e:
                # Log Crash/Error
                process_time = (time.time() - start_time) * 1000
                logger.error(f"❌ Failed: {str(e)} | Took: {process_time:.2f}ms")
                
                # Re-raise the error so FastAPI's exception handler catches it
                raise e