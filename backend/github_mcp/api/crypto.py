"""Token encryption/decryption using Fernet symmetric encryption."""

import os
import base64

from cryptography.fernet import Fernet, InvalidToken
from loguru import logger


def _get_fernet() -> Fernet:
    key = os.environ.get("TOKEN_ENCRYPTION_KEY", "")
    if not key:
        raise RuntimeError("TOKEN_ENCRYPTION_KEY is not set.")
    # Accept already-valid Fernet keys (44-char base64url) or raw base64-encoded 32-byte keys
    try:
        return Fernet(key.encode())
    except Exception:
        # Apply correct base64 padding before decoding
        padding_needed = (4 - len(key) % 4) % 4
        padded = key + "=" * padding_needed
        raw = base64.urlsafe_b64decode(padded)[:32]
        if len(raw) < 32:
            raise ValueError(
                "TOKEN_ENCRYPTION_KEY is too short; provide a valid Fernet key "
                "(generate with: python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\")"
            )
        return Fernet(base64.urlsafe_b64encode(raw))


def encrypt_token(plaintext: str) -> str:
    """Encrypt a plaintext token string and return a base64-safe ciphertext."""
    f = _get_fernet()
    ciphertext = f.encrypt(plaintext.encode())
    return ciphertext.decode()


def decrypt_token(ciphertext: str) -> str:
    """Decrypt a previously encrypted token. Raises ValueError on tampering."""
    f = _get_fernet()
    try:
        return f.decrypt(ciphertext.encode()).decode()
    except InvalidToken:
        logger.error("crypto | token decryption failed — possible tampering")
        raise ValueError("Token decryption failed")
