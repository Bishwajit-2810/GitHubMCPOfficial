"""Pull request tool for GitHub MCP Server.

Provides functionality to create pull requests.
"""

from typing import Optional
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GITHUB_API
from ..config import DEFAULT_OWNER, DEFAULT_REPO
from ..core.github_api import _headers, _raise_for_status


def register_create_pull_request_tool(mcp: FastMCP):
    """Register the create_pull_request tool with the MCP server."""

    @mcp.tool()
    async def create_pull_request(
        title: str,
        head: str,
        base: str = "main",
        body: str = "",
        draft: bool = False,
        owner: Optional[str] = None,
        repo: Optional[str] = None,
    ) -> dict:
        """
        Open a pull request on GitHub.

        Args:
            title:  PR title.
            head:   Source branch (the one with your changes).
            base:   Target branch to merge into (default "main").
            body:   PR description (Markdown supported).
            draft:  Open as a draft PR (default False).
            owner:  Repo owner (defaults to GITHUB_OWNER in .env).
            repo:   Repository name (defaults to GITHUB_REPO in .env).
        """
        owner = owner or DEFAULT_OWNER
        repo = repo or DEFAULT_REPO

        logger.info(f"create_pull_request | {owner}/{repo} | {head} -> {base}")
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{GITHUB_API}/repos/{owner}/{repo}/pulls",
                headers=_headers(),
                json={
                    "title": title,
                    "head": head,
                    "base": base,
                    "body": body,
                    "draft": draft,
                },
            )
        _raise_for_status(resp)
        data = resp.json()
        logger.info(f"create_pull_request | PR #{data['number']} → {data['html_url']}")
        return {
            "repo": f"{owner}/{repo}",
            "number": data["number"],
            "title": data["title"],
            "state": data["state"],
            "draft": data["draft"],
            "html_url": data["html_url"],
            "head": data["head"]["ref"],
            "base": data["base"]["ref"],
            "created_at": data["created_at"],
        }
