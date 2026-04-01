import sys
import os
from pathlib import Path
from loguru import logger

# 1. Setup Paths
PROJECT_ROOT = Path(__file__).parent.parent.parent
LOGS_DIR = PROJECT_ROOT / "logs"
LOG_FILE = LOGS_DIR / "bank.log"

if not os.path.exists(LOGS_DIR):
    os.makedirs(LOGS_DIR)

# 2. Custom Filter to handle Context
# If a log doesn't have a request_id, we label it "SYSTEM"
def request_id_filter(record):
    if "request_id" not in record["extra"]:
        record["extra"]["request_id"] = "SYSTEM"
    return True

# 3. Configure Logger
logger.remove()

# Format: Time | Level | Request ID | File:Function:Line | Message
# We align Request ID to 8 chars for neatness
log_format = (
    "<green>{time:DD-MM-YYYY HH:mm:ss.SSS}</green> | "
    "<level>{level: <8}</level> | "
    "<cyan>{extra[request_id]: <8}</cyan> | " 
    "<cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - "
    "<level>{message}</level>"
)

# Console Handler
logger.add(
    sys.stderr, 
    format=log_format, 
    level="INFO", 
    colorize=True,
    filter=request_id_filter
)

# File Handler
logger.add(
    str(LOG_FILE),
    format="{time:DD-MM-YYYY HH:mm:ss.SSS} | {level: <8} | {extra[request_id]: <8} | {name}:{function}:{line} - {message}",
    rotation="10 MB",
    retention="10 days",
    compression="zip",
    level="INFO",
    filter=request_id_filter
)

logger.info("Logger initialized.")