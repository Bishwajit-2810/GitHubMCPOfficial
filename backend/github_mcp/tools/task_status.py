"""Update task status tool for GitHub MCP Server.

Provides functionality to update the status of tasks on GitHub Projects v2 boards.
"""

from typing import Optional
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GRAPHQL_URL
from ..config import DEFAULT_OWNER, DEFAULT_PROJECT
from ..core.github_api import _gql_headers, _gql_check
from ..utils.project_helpers import _resolve_project, _find_field


def register_update_task_status_tool(mcp: FastMCP):
    """Register the update_task_status tool with the MCP server."""

    @mcp.tool()
    async def update_task_status(
        item_id: str,
        status: str,
        project_number: Optional[int] = None,
        owner: Optional[str] = None,
    ) -> dict:
        """
        Change the Status column of any existing item on a Projects v2 board.

        Get item_id from list_project_tasks — it is the "item_id" field on each
        returned item, e.g. "PVTI_lADOBqfXXs4AbcDE". This is stable and never
        changes regardless of item order or filters.

        Status must match an existing column name (case-insensitive).

        Args:
            item_id:        The item_id from list_project_tasks (starts with PVTI_).
            status:         New status e.g. "Todo", "In Progress", "Done".
            project_number: Project number (defaults to PROJECT_ID in .env).
            owner:          Project owner (defaults to GITHUB_OWNER in .env).
        """
        # Hard guard: item_id is mandatory
        if not item_id or not item_id.strip():
            raise ValueError(
                "item_id is required. Call list_project_tasks first and copy "
                "the 'item_id' field from the item you want to update."
            )
        if not item_id.startswith("PVTI_"):
            raise ValueError(
                f"item_id looks invalid: {item_id!r}. "
                "A valid item_id starts with 'PVTI_' and comes from list_project_tasks."
            )

        owner = owner or DEFAULT_OWNER
        project_number = project_number or DEFAULT_PROJECT

        logger.info(
            f"update_task_status | {owner} project=#{project_number} "
            f"item={item_id!r} -> '{status}'"
        )

        async with httpx.AsyncClient() as client:
            proj = await _resolve_project(client, owner, project_number)
            project_id = proj["id"]

            sf = _find_field(proj, "Status")
            status_field_id = sf["id"]
            status_option_id = None
            for opt in sf.get("options", []):
                if opt["name"].lower() == status.lower():
                    status_option_id = opt["id"]
                    break
            if not status_option_id:
                available = [o["name"] for o in sf.get("options", [])]
                raise RuntimeError(
                    f"Status '{status}' not found. Available: {available}"
                )

            mutation = f"""
            mutation {{
              updateProjectV2ItemFieldValue(input: {{
                projectId: "{project_id}"
                itemId:    "{item_id}"
                fieldId:   "{status_field_id}"
                value:     {{ singleSelectOptionId: "{status_option_id}" }}
              }}) {{ projectV2Item {{ id }} }}
            }}"""

            r = await client.post(
                GRAPHQL_URL, headers=_gql_headers(), json={"query": mutation}
            )
            _gql_check(r)

        logger.info(f"update_task_status | {item_id} → '{status}' ✓")
        return {
            "item_id": item_id,
            "status_updated": status,
            "project_id": project_id,
        }
