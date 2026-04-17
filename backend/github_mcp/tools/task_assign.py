"""Assign task tool for GitHub MCP Server.

Provides functionality to assign users and labels to GitHub issues.
"""

from typing import Optional
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GITHUB_API
from ..config import DEFAULT_OWNER, DEFAULT_REPO
from ..core.github_api import _headers, _raise_for_status


def register_assign_task_tool(mcp: FastMCP):
    """Register the assign_task tool with the MCP server."""

    @mcp.tool()
    async def assign_task(
        issue_number: int,
        assignees: list[str],
        labels: Optional[list[str]] = None,
        repo: Optional[str] = None,
        owner: Optional[str] = None,
    ) -> dict:
        """
        Assign users to a GitHub Issue and optionally apply labels.
        Missing labels are auto-created so the call never fails on a new label.

        Args:
            issue_number: Issue number from the URL.
            assignees:    GitHub usernames. Replaces current assignees ([] to clear).
            labels:       Labels to apply; merged with existing. None = no change.
            repo:         Repository name (defaults to GITHUB_REPO in .env).
            owner:        Repo owner (defaults to GITHUB_OWNER in .env).
        """
        owner = owner or DEFAULT_OWNER
        repo = repo or DEFAULT_REPO

        logger.info(
            f"assign_task | {owner}/{repo}#{issue_number} "
            f"assignees={assignees} labels={labels}"
        )

        issue_api = f"{GITHUB_API}/repos/{owner}/{repo}/issues/{issue_number}"

        async with httpx.AsyncClient() as client:
            cur = await client.get(issue_api, headers=_headers())
            _raise_for_status(cur)
            existing_labels = [lb["name"] for lb in cur.json().get("labels", [])]

            if labels:
                rl = await client.get(
                    f"{GITHUB_API}/repos/{owner}/{repo}/labels",
                    headers=_headers(),
                    params={"per_page": 100},
                )
                _raise_for_status(rl)
                repo_labels = {lb["name"] for lb in rl.json()}
                import random

                for lbl in labels:
                    if lbl not in repo_labels:
                        color = f"{random.randint(0, 0xFFFFFF):06x}"
                        cr = await client.post(
                            f"{GITHUB_API}/repos/{owner}/{repo}/labels",
                            headers=_headers(),
                            json={"name": lbl, "color": color},
                        )
                        if cr.status_code not in (201, 422):
                            _raise_for_status(cr)
                        logger.info(f"assign_task | auto-created label '{lbl}'")

            merged = list(dict.fromkeys(existing_labels + (labels or [])))
            patch: dict = {"assignees": assignees}
            if labels is not None:
                patch["labels"] = merged

            pr = await client.patch(issue_api, headers=_headers(), json=patch)
            _raise_for_status(pr)
            data = pr.json()

        out_assignees = [a["login"] for a in data.get("assignees", [])]
        out_labels = [lb["name"] for lb in data.get("labels", [])]
        logger.info(f"assign_task | #{issue_number} → {out_assignees} {out_labels}")
        return {
            "repo": f"{owner}/{repo}",
            "issue_number": data["number"],
            "title": data["title"],
            "state": data["state"],
            "html_url": data["html_url"],
            "assignees": out_assignees,
            "labels": out_labels,
            "updated_at": data["updated_at"],
        }
