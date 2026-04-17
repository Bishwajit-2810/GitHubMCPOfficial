"""Create project task tool for GitHub MCP Server.

Provides functionality to create tasks on GitHub Projects v2 boards.
"""

from typing import Optional
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GITHUB_API, GRAPHQL_URL
from ..config import DEFAULT_OWNER, DEFAULT_REPO, DEFAULT_PROJECT
from ..core.github_api import _headers, _gql_headers, _gql_check, _raise_for_status
from ..utils.project_helpers import _resolve_project, _find_field


def register_create_project_task_tool(mcp: FastMCP):
    """Register the create_project_task tool with the MCP server."""

    @mcp.tool()
    async def create_project_task(
        title: str,
        body: str = "",
        status: Optional[str] = None,
        project_number: Optional[int] = None,
        repo: Optional[str] = None,
        owner: Optional[str] = None,
        assignee: Optional[str] = None,
        label: Optional[str] = None,
    ) -> dict:
        """
        Create a task and add it to a GitHub Projects v2 board.

        If `repo` is given a real Issue is created and linked to the project.
        Otherwise a draft item is added directly to the board.
        Optionally sets the Status column immediately.

        Args:
            title:          Task title.
            body:           Description (Markdown supported).
            status:         Status column name e.g. "Todo", "In Progress", "Done".
            project_number: Project number from the URL (defaults to PROJECT_ID in .env).
            repo:           Repo name — if set, creates a real Issue (defaults to GITHUB_REPO).
            owner:          Owner (defaults to GITHUB_OWNER in .env).
            assignee:       GitHub username to assign.
            label:          Label name (must already exist in the repo).
        """
        owner = owner or DEFAULT_OWNER
        repo = repo or DEFAULT_REPO
        project_number = project_number or DEFAULT_PROJECT

        logger.info(
            f"create_project_task | {owner} project=#{project_number} "
            f"title={title!r} status={status!r}"
        )

        async with httpx.AsyncClient() as client:

            # ── Resolve project + Status field in one shot ────────────────────
            proj = await _resolve_project(client, owner, project_number)
            project_id = proj["id"]
            project_title = proj["title"]
            logger.info(
                f"create_project_task | project='{project_title}' id={project_id}"
            )

            status_field_id = None
            status_option_id = None
            if status:
                sf = _find_field(proj, "Status")
                status_field_id = sf["id"]
                for opt in sf.get("options", []):
                    if opt["name"].lower() == status.lower():
                        status_option_id = opt["id"]
                        break
                if not status_option_id:
                    available = [o["name"] for o in sf.get("options", [])]
                    raise RuntimeError(
                        f"Status '{status}' not found. Available: {available}"
                    )

            issue_url = issue_number = None

            # ── Step 2a: real Issue ───────────────────────────────────────────
            if repo:
                issue_payload: dict = {"title": title, "body": body}
                if assignee:
                    issue_payload["assignees"] = [assignee]
                if label:
                    issue_payload["labels"] = [label]

                ir = await client.post(
                    f"{GITHUB_API}/repos/{owner}/{repo}/issues",
                    headers=_headers(),
                    json=issue_payload,
                )
                _raise_for_status(ir)
                idata = ir.json()
                issue_url = idata["html_url"]
                issue_number = idata["number"]
                content_id = idata["node_id"]

                # Link issue to project board
                add_r = await client.post(
                    GRAPHQL_URL,
                    headers=_gql_headers(),
                    json={
                        "query": """
                        mutation($pid: ID!, $cid: ID!) {
                          addProjectV2ItemById(input: {projectId: $pid, contentId: $cid}) {
                            item { id }
                          }
                        }""",
                        "variables": {"pid": project_id, "cid": content_id},
                    },
                )
                d = _gql_check(add_r)
                item_id = d["data"]["addProjectV2ItemById"]["item"]["id"]

            # ── Step 2b: draft ────────────────────────────────────────────────
            else:
                draft_r = await client.post(
                    GRAPHQL_URL,
                    headers=_gql_headers(),
                    json={
                        "query": """
                        mutation($pid: ID!, $title: String!, $body: String) {
                          addProjectV2DraftIssue(input: {
                            projectId: $pid, title: $title, body: $body
                          }) { projectItem { id } }
                        }""",
                        "variables": {"pid": project_id, "title": title, "body": body},
                    },
                )
                d = _gql_check(draft_r)
                item_id = d["data"]["addProjectV2DraftIssue"]["projectItem"]["id"]

            # ── Step 3: set Status ────────────────────────────────────────────
            status_set = None
            if status_field_id and status_option_id and item_id:
                # FIX: singleSelectOptionId must be inlined, NOT passed as variable
                st_mutation = f"""
                mutation {{
                  updateProjectV2ItemFieldValue(input: {{
                    projectId: "{project_id}"
                    itemId:    "{item_id}"
                    fieldId:   "{status_field_id}"
                    value:     {{ singleSelectOptionId: "{status_option_id}" }}
                  }}) {{ projectV2Item {{ id }} }}
                }}"""
                st_r = await client.post(
                    GRAPHQL_URL, headers=_gql_headers(), json={"query": st_mutation}
                )
                _gql_check(st_r)
                status_set = status
                logger.info(f"create_project_task | status set to '{status}'")

        logger.info(f"create_project_task | done item_id={item_id}")
        result = {
            "project_title": project_title,
            "project_id": project_id,
            "item_id": item_id,
            "title": title,
            "status": status_set,
            "type": "issue" if repo else "draft_issue",
        }
        if issue_url:
            result["issue_url"] = issue_url
            result["issue_number"] = issue_number
        return result
