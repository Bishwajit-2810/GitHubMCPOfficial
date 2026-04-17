"""Create project field tool for GitHub MCP Server.

Provides functionality to create custom fields on GitHub Projects v2 boards.
"""

from typing import Optional
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GRAPHQL_URL
from ..config import DEFAULT_OWNER, DEFAULT_PROJECT
from ..core.github_api import _gql_headers, _gql_check
from ..utils.project_helpers import _resolve_project


def register_create_project_field_tool(mcp: FastMCP):
    """Register the create_project_field tool with the MCP server."""

    @mcp.tool()
    async def create_project_field(
        field_name: str,
        field_type: str,
        project_number: Optional[int] = None,
        owner: Optional[str] = None,
    ) -> dict:
        """
        Add a custom field to a GitHub Projects v2 board.

        Supported types:
          "text"   - free-form text
          "number" - integer or decimal  (use for story points, hours, etc.)
          "date"   - calendar date       (use for Start Date, End Date, Due Date, etc.)

        Args:
            field_name:     Display name e.g. "Story Points", "Start Date", "End Date".
            field_type:     One of "text", "number", "date" (case-insensitive).
            project_number: Project number (defaults to PROJECT_ID in .env).
            owner:          Project owner (defaults to GITHUB_OWNER in .env).
        """
        owner = owner or DEFAULT_OWNER
        project_number = project_number or DEFAULT_PROJECT

        TYPE_MAP = {"text": "TEXT", "number": "NUMBER", "date": "DATE"}
        gql_type = TYPE_MAP.get(field_type.lower())
        if not gql_type:
            raise ValueError(
                f"Invalid field_type '{field_type}'. Use one of: text, number, date."
            )

        logger.info(
            f"create_project_field | {owner} project=#{project_number} "
            f"name='{field_name}' type={gql_type}"
        )

        async with httpx.AsyncClient() as client:
            proj = await _resolve_project(client, owner, project_number)
            project_id = proj["id"]

            # Check if a field with this name already exists — if so, return it
            # instead of crashing with "Name has already been taken".
            for node in proj.get("fields", {}).get("nodes", []):
                if node and node.get("name", "").lower() == field_name.lower():
                    existing_type = node.get("dataType", "UNKNOWN")
                    logger.info(
                        f"create_project_field | field '{field_name}' already exists "
                        f"(id={node['id']} type={existing_type}) — returning existing"
                    )
                    return {
                        "project_id": project_id,
                        "field_id": node["id"],
                        "field_name": node["name"],
                        "field_type": existing_type,
                        "already_existed": True,
                    }

            # Correct mutation per GitHub docs: createProjectV2Field
            mutation = f"""
            mutation {{
              createProjectV2Field(input: {{
                projectId: "{project_id}"
                dataType:  {gql_type}
                name:      "{field_name}"
              }}) {{
                projectV2Field {{
                  ... on ProjectV2Field {{
                    id
                    name
                    dataType
                  }}
                }}
              }}
            }}"""

            r = await client.post(
                GRAPHQL_URL, headers=_gql_headers(), json={"query": mutation}
            )
            d = _gql_check(r)
            fd = d["data"]["createProjectV2Field"]["projectV2Field"]

        logger.info(
            f"create_project_field | created '{field_name}' id={fd.get('id')} ✓"
        )
        return {
            "project_id": project_id,
            "field_id": fd.get("id"),
            "field_name": fd.get("name"),
            "field_type": fd.get("dataType"),
            "already_existed": False,
        }
