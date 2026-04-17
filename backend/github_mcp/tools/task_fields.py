"""Set task fields tool for GitHub MCP Server.

Provides functionality to set custom field values on GitHub Projects v2 task items.
"""

from typing import Optional
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GRAPHQL_URL
from ..config import DEFAULT_OWNER, DEFAULT_PROJECT
from ..core.github_api import _gql_headers, _gql_check
from ..utils.project_helpers import _resolve_project, _inline_value


def register_set_task_fields_tool(mcp: FastMCP):
    """Register the set_task_fields tool with the MCP server."""

    @mcp.tool()
    async def set_task_fields(
        item_id: str,
        fields: dict,
        project_number: Optional[int] = None,
        owner: Optional[str] = None,
    ) -> dict:
        """
        Set one or more field values on a project item.

        STEP 1 — always call list_project_tasks FIRST.
          - Copy item_id from the item you want to update  (e.g. "PVTI_abc123")
          - Copy field names exactly from custom_field_names in the response

        STEP 2 — call this tool with those exact values.

        item_id is MANDATORY. Never assume or reuse one from a previous call.

        Field names must match the project exactly (case-insensitive).
        If a name is wrong this tool raises an error immediately listing all
        valid field names — nothing is updated until all names are correct.

        Value formats:
          date   →  "YYYY-MM-DD"   e.g. "2026-03-15"
          number →  int/float      e.g. 8
          text   →  any string     e.g. "Blocked by auth"

        Example:
          item_id = "PVTI_lADOBqfXXs4AbcDE"
          fields  = {
            "Start Date":   "2026-03-01",
            "End Date":     "2026-03-31",
            "Story Points": 8
          }

        Args:
            item_id:        MANDATORY — from list_project_tasks, starts with PVTI_.
            fields:         Dict of {field_name: value}. Names must match exactly.
            project_number: Project number (defaults to PROJECT_ID in .env).
            owner:          Project owner (defaults to GITHUB_OWNER in .env).
        """
        # ── item_id is mandatory — hard fail immediately, never silently skip ─────
        if not item_id or not str(item_id).strip():
            raise ValueError(
                "item_id is mandatory. "
                "Call list_project_tasks first and copy the 'item_id' from the item "
                "you want to update. Do NOT assume or reuse a previous item_id."
            )
        item_id = str(item_id).strip()
        if not item_id.startswith("PVTI_"):
            raise ValueError(
                f"item_id '{item_id}' is invalid — it must start with 'PVTI_'. "
                "Get it from list_project_tasks."
            )

        owner = owner or DEFAULT_OWNER
        project_number = project_number or DEFAULT_PROJECT

        logger.info(
            f"set_task_fields | {owner} project=#{project_number} "
            f"item={item_id!r} fields={list(fields.keys())}"
        )

        async with httpx.AsyncClient() as client:
            proj = await _resolve_project(client, owner, project_number)
            project_id = proj["id"]

            # Build lookup: field_name.lower() -> {id, name, dataType}
            TYPENAME_TO_DTYPE = {
                "ProjectV2SingleSelectField": "SINGLE_SELECT",
                "ProjectV2IterationField": "ITERATION",
            }
            field_lookup: dict = {}
            for node in proj.get("fields", {}).get("nodes", []):
                if not node or not node.get("name"):
                    continue
                typename = node.get("__typename", "ProjectV2Field")
                data_type = (
                    TYPENAME_TO_DTYPE.get(typename) or node.get("dataType") or "TEXT"
                )
                field_lookup[node["name"].lower()] = {
                    "id": node["id"],
                    "name": node["name"],
                    "dataType": data_type,
                }
                logger.info(
                    f"set_task_fields | field '{node['name']}' "
                    f"__typename={typename} dataType={data_type}"
                )

            available_names = [meta["name"] for meta in field_lookup.values()]

            # ── Validate ALL field names before touching anything ────────────────
            bad_fields = [fn for fn in fields if fn.lower() not in field_lookup]
            if bad_fields:
                raise ValueError(
                    f"Unknown field name(s): {bad_fields}. "
                    f"Available fields on this project: {available_names}. "
                    "Field names must match exactly (case-insensitive). "
                    "Call list_project_tasks to see custom_field_names."
                )

            # ── Apply each field value ───────────────────────────────────────────
            results = {}
            for field_name, value in fields.items():
                meta = field_lookup[field_name.lower()]
                field_id = meta["id"]
                data_type = meta["dataType"]

                # Value block MUST be inlined in the query string.
                value_block = _inline_value(data_type, value)

                mutation = f"""
                mutation {{
                  updateProjectV2ItemFieldValue(input: {{
                    projectId: "{project_id}"
                    itemId:    "{item_id}"
                    fieldId:   "{field_id}"
                    value:     {value_block}
                  }}) {{ projectV2Item {{ id }} }}
                }}"""

                r = await client.post(
                    GRAPHQL_URL, headers=_gql_headers(), json={"query": mutation}
                )
                _gql_check(r)
                results[field_name] = value
                logger.info(
                    f"set_task_fields | ✓ '{field_name}' ({data_type}) = {value!r}"
                )

        logger.info(
            f"set_task_fields | done — {len(results)} field(s) updated on {item_id}"
        )
        return {
            "item_id": item_id,
            "project_id": project_id,
            "fields_set": results,
            "available_field_names": available_names,
        }
