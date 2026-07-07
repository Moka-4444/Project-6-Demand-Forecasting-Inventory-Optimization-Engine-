"""
Simple token-based authentication for the CrunchOps API.
"""

import secrets
from typing import Optional

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

# Demo users — manager (executive) and staff (operator) roles
USERS = {
    "manager@stocksense.com": {"password": "password123", "role": "executive"},
    "staff@stocksense.com": {"password": "password123", "role": "operator"},
    "executive@crunchops.com": {"password": "password123", "role": "executive"},
    "operator@crunchops.com": {"password": "password123", "role": "operator"},
}

# In-memory active sessions (token -> email)
_active_tokens: dict[str, str] = {}

_bearer = HTTPBearer(auto_error=False)


def authenticate_user(email: str, password: str) -> Optional[dict]:
    """Validate credentials and return user info."""
    user = USERS.get(email.strip().lower())
    if user and user["password"] == password:
        return {"email": email.strip().lower(), "role": user["role"]}
    return None


def create_token(email: str) -> str:
    """Create a session token for the authenticated user."""
    token = secrets.token_urlsafe(32)
    _active_tokens[token] = email.strip().lower()
    return token


def revoke_token(token: str) -> None:
    """Remove a session token."""
    _active_tokens.pop(token, None)


def get_user_from_token(token: str) -> Optional[dict]:
    """Resolve token to user info."""
    email = _active_tokens.get(token)
    if not email:
        return None
    user = USERS.get(email)
    if not user:
        return None
    return {"email": email, "role": user["role"]}


def require_auth(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> dict:
    """FastAPI dependency — require valid Bearer token."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Authentication required")
    user = get_user_from_token(credentials.credentials)
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user
