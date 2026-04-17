"""Create branch tool for GitHub MCP Server.

Provides functionality to create new branches in a GitHub repository.
"""

from typing import Optional
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GITHUB_API
from ..config import DEFAULT_OWNER, DEFAULT_REPO
from ..core.github_api import _headers, _raise_for_status


def register_create_branch_tool(mcp: FastMCP):
    """Register the create_branch tool with the MCP server."""

    @mcp.tool()
    async def create_branch(
        branch: str,
        source_branch: str = "main",
        owner: Optional[str] = None,
        repo: Optional[str] = None,
    ) -> dict:
        """
        Create a new branch from an existing branch.

        Args:
            branch:        Name of the new branch.
            source_branch: Branch to copy from (default "main").
            owner:         Repo owner (defaults to GITHUB_OWNER in .env).
            repo:          Repository name (defaults to GITHUB_REPO in .env).
        """
        owner = owner or DEFAULT_OWNER
        repo = repo or DEFAULT_REPO

        logger.info(f"create_branch | {owner}/{repo} | {source_branch} -> {branch}")
        async with httpx.AsyncClient() as client:
            r = await client.get(
                f"{GITHUB_API}/repos/{owner}/{repo}/git/ref/heads/{source_branch}",
                headers=_headers(),
            )
            _raise_for_status(r)
            sha = r.json()["object"]["sha"]

            cr = await client.post(
                f"{GITHUB_API}/repos/{owner}/{repo}/git/refs",
                headers=_headers(),
                json={"ref": f"refs/heads/{branch}", "sha": sha},
            )
            _raise_for_status(cr)
            data = cr.json()

        logger.info(f"create_branch | created {branch} @ {data['object']['sha'][:7]}")
        return {
            "repo": f"{owner}/{repo}",
            "branch": branch,
            "source": source_branch,
            "sha": data["object"]["sha"],
            "ref": data["ref"],
            "url": data["url"],
        }
