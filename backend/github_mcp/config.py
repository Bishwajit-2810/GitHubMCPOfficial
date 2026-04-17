"""Configuration module for GitHub MCP Server.

Loads environment variables and provides configuration constants.
"""

import os
from dotenv import load_dotenv
from loguru import logger

# Load environment variables from .env file
load_dotenv()

# GitHub configuration
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
DEFAULT_OWNER = os.environ.get("GITHUB_OWNER", "")
DEFAULT_REPO = os.environ.get("GITHUB_REPO", "")
DEFAULT_PROJECT = int(os.environ.get("PROJECT_ID", "0"))


def validate_config() -> None:
    """Validate that required environment variables are set."""
    if not GITHUB_TOKEN:
        raise RuntimeError("GITHUB_TOKEN is not set. Add it to your .env file.")

    logger.info(f"Configuration loaded:")
    logger.info(f"  Token   : {'✓ loaded' if GITHUB_TOKEN else '✗ MISSING'}")
    logger.info(f"  Owner   : {DEFAULT_OWNER or '✗ MISSING'}")
    logger.info(f"  Repo    : {DEFAULT_REPO or '✗ MISSING'}")
    logger.info(f"  Project : {DEFAULT_PROJECT or '✗ MISSING'}")
