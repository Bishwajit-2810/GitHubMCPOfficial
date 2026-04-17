"""Create/update file tool for GitHub MCP Server.

Provides functionality to create or update files in a GitHub repository.
"""

from typing import Optional
import base64
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GITHUB_API
from ..config import DEFAULT_OWNER, DEFAULT_REPO
from ..core.github_api import _headers, _raise_for_status


def register_create_file_tool(mcp: FastMCP):
    """Register the create_file tool with the MCP server."""

    @mcp.tool()
    async def create_file(
        file_path: str,
        content: str,
        commit_message: str,
        branch: str = "main",
        owner: Optional[str] = None,
        repo: Optional[str] = None,
    ) -> dict:
        """
        Create or update a file in a GitHub repository.

        Args:
            file_path:      Path inside the repo e.g. "src/hello.py".
            content:        Plain-text content for the file.
            commit_message: Git commit message.
            branch:         Target branch (default "main").
            owner:          Repo owner (defaults to GITHUB_OWNER in .env).
            repo:           Repository name (defaults to GITHUB_REPO in .env).
        """
        owner = owner or DEFAULT_OWNER
        repo = repo or DEFAULT_REPO

        logger.info(f"create_file | {owner}/{repo} | {file_path} on {branch}")
        b64 = base64.b64encode(content.encode()).decode()
        url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{file_path}"
        payload: dict = {"message": commit_message, "content": b64, "branch": branch}

        async with httpx.AsyncClient() as client:
            ex = await client.get(url, headers=_headers(), params={"ref": branch})
            if ex.status_code == 200:
                payload["sha"] = ex.json()["sha"]
            resp = await client.put(url, headers=_headers(), json=payload)
        _raise_for_status(resp)

        data = resp.json()
        action = "updated" if "sha" in payload else "created"
        logger.info(f"create_file | {action} {file_path}")
        return {
            "repo": f"{owner}/{repo}",
            "action": action,
            "file_path": file_path,
            "branch": branch,
            "commit_sha": data["commit"]["sha"],
            "commit_url": data["commit"]["html_url"],
            "blob_url": data["content"]["html_url"],
        }
