"""List files tool for GitHub MCP Server.

Provides functionality to list files and directories in a GitHub repository.
"""

from typing import Optional
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GITHUB_API
from ..config import DEFAULT_OWNER, DEFAULT_REPO
from ..core.github_api import _headers, _raise_for_status


def register_list_files_tool(mcp: FastMCP):
    """Register the list_files tool with the MCP server."""

    @mcp.tool()
    async def list_files(
        path: str = "",
        ref: Optional[str] = None,
        owner: Optional[str] = None,
        repo: Optional[str] = None,
    ) -> dict:
        """
        List files and directories inside a GitHub repository path.

        Args:
            path:  Path inside the repo (default = root "").
            ref:   Branch / tag / SHA to read from (default = default branch).
            owner: Repo owner (defaults to GITHUB_OWNER in .env).
            repo:  Repository name (defaults to GITHUB_REPO in .env).
        """
        owner = owner or DEFAULT_OWNER
        repo = repo or DEFAULT_REPO
        url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{path}"

        logger.info(f"list_files | {owner}/{repo} | path={path!r} ref={ref}")
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                url, headers=_headers(), params={"ref": ref} if ref else {}
            )
        _raise_for_status(resp)

        raw = resp.json()
        items = raw if isinstance(raw, list) else [raw]
        logger.info(f"list_files | {len(items)} items")
        return {
            "repo": f"{owner}/{repo}",
            "path": path or "/",
            "count": len(items),
            "items": [
                {
                    "name": i["name"],
                    "type": i["type"],
                    "size": i.get("size"),
                    "sha": i["sha"],
                    "html_url": i.get("html_url"),
                    "download_url": i.get("download_url"),
                }
                for i in items
            ],
        }
