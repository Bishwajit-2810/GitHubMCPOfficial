"""Core GitHub API helper functions.

Provides utilities for making authenticated requests to GitHub's REST and GraphQL APIs.
"""

import httpx
from loguru import logger
from ..config import GITHUB_TOKEN
from ..constants import GITHUB_API


def _headers(token: str | None = None) -> dict:
    """Get standard GitHub API headers with authentication."""
    tok = token or GITHUB_TOKEN
    if not tok:
        raise RuntimeError("GITHUB_TOKEN is not set. Add it to your .env file.")
    return {
        "Authorization": f"Bearer {tok}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def _gql_headers(token: str | None = None) -> dict:
    """Get GitHub GraphQL API headers with authentication and content type."""
    return {**_headers(token), "Content-Type": "application/json"}


def _raise_for_status(resp: httpx.Response) -> None:
    """Raise an error if the HTTP response indicates a failure."""
    if resp.status_code >= 400:
        try:
            detail = resp.json()
        except Exception:
            detail = resp.text
        logger.error(f"GitHub API {resp.status_code}: {detail}")
        raise RuntimeError(f"GitHub API error {resp.status_code}: {detail}")


def _gql_check(resp: httpx.Response) -> dict:
    """Raise on HTTP errors AND on GraphQL-level errors. Return parsed JSON."""
    _raise_for_status(resp)
    payload = resp.json()
    errs = payload.get("errors")
    if errs:
        msg = "; ".join(e.get("message", str(e)) for e in errs)
        logger.error(f"GraphQL error: {msg}")
        raise RuntimeError(f"GraphQL error: {msg}")
    return payload


async def get_default_branch(
    owner: str, repo: str, token: str | None = None
) -> str:
    """Fetch and return the repository's default branch name."""
    async with httpx.AsyncClient() as client:
        r = await client.get(
            f"{GITHUB_API}/repos/{owner}/{repo}",
            headers=_headers(token),
        )
        _raise_for_status(r)
        branch = r.json().get("default_branch", "main")
        logger.debug(f"get_default_branch | {owner}/{repo} -> {branch}")
        return branch
