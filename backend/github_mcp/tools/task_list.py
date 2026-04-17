"""List project tasks tool for GitHub MCP Server.

Provides functionality to list items on GitHub Projects v2 boards with pagination.
"""

from typing import Optional
import httpx
from loguru import logger
from fastmcp import FastMCP

from ..constants import GRAPHQL_URL, PAGE_SIZE, BUILTIN_FIELDS
from ..config import DEFAULT_OWNER, DEFAULT_PROJECT
from ..core.github_api import _gql_headers, _gql_check


def register_list_project_tasks_tool(mcp: FastMCP):
    """Register the list_project_tasks tool with the MCP server."""

    @mcp.tool()
    async def list_project_tasks(
        project_number: Optional[int] = None,
        owner: Optional[str] = None,
        offset: int = 0,
        limit: int = 50,
    ) -> dict:
        """
        List items on a GitHub Projects v2 board with custom offset pagination.

        Supports any range: offset=200, limit=150 returns items 200-349.
        GitHub allows max 100 per GraphQL page so large ranges are broken into
        multiple internal requests automatically.

        Returns per item: title, type, status, all custom fields (text/number/date),
        assignees, labels, issue number, state, URL.

        Args:
            project_number: Project number (defaults to PROJECT_ID in .env).
            owner:          Owner (defaults to GITHUB_OWNER in .env).
            offset:         0-based index of the first item to return (default 0).
            limit:          How many items to return (default 50).
        """
        owner = owner or DEFAULT_OWNER
        project_number = project_number or DEFAULT_PROJECT
        limit = max(1, limit)

        logger.info(
            f"list_project_tasks | {owner} project=#{project_number} "
            f"offset={offset} limit={limit}"
        )

        _USER_ITEMS = """
        query($login: String!, $number: Int!, $first: Int!, $after: String) {
          user(login: $login) {
            projectV2(number: $number) {
              id title
              fields(first: 50) {
                nodes {
                  __typename
                  ... on ProjectV2Field             { id name dataType }
                  ... on ProjectV2SingleSelectField  { id name options { id name } }
                  ... on ProjectV2IterationField     { id name }
                }
              }
              items(first: $first, after: $after) {
                totalCount
                pageInfo { endCursor hasNextPage }
                nodes {
                  id type
                  fieldValues(first: 20) {
                    nodes {
                      __typename
                      ... on ProjectV2ItemFieldSingleSelectValue {
                        name
                        field { ... on ProjectV2SingleSelectField { name } }
                      }
                      ... on ProjectV2ItemFieldTextValue {
                        text
                        field { ... on ProjectV2Field { name } }
                      }
                      ... on ProjectV2ItemFieldNumberValue {
                        number
                        field { ... on ProjectV2Field { name } }
                      }
                      ... on ProjectV2ItemFieldDateValue {
                        date
                        field { ... on ProjectV2Field { name } }
                      }
                    }
                  }
                  content {
                    ... on Issue {
                      number title state url body
                      assignees(first: 5) { nodes { login } }
                      labels(first: 10)   { nodes { name color } }
                      createdAt updatedAt
                    }
                    ... on PullRequest {
                      number title state url
                      assignees(first: 5) { nodes { login } }
                      createdAt
                    }
                    ... on DraftIssue {
                      title body
                      assignees(first: 5) { nodes { login } }
                      createdAt: updatedAt
                    }
                  }
                }
              }
            }
          }
        }"""

        _ORG_ITEMS = _USER_ITEMS.replace(
            "user(login: $login) {", "organization(login: $login) {"
        )

        def _parse_fv(nodes: list) -> dict:
            out = {}
            for fv in nodes:
                if not fv:
                    continue
                fname = (fv.get("field") or {}).get("name")
                if not fname:
                    continue
                for key in ("name", "text", "number", "date"):
                    if key in fv:
                        out[fname] = fv[key]
                        break
            return out

        async with httpx.AsyncClient() as client:

            # Resolve entity type with first page
            resolved_query = None
            resolved_key = None
            proj_data = None

            for q, key in ((_USER_ITEMS, "user"), (_ORG_ITEMS, "organization")):
                r = await client.post(
                    GRAPHQL_URL,
                    headers=_gql_headers(),
                    json={
                        "query": q,
                        "variables": {
                            "login": owner,
                            "number": project_number,
                            "first": PAGE_SIZE,
                            "after": None,
                        },
                    },
                )
                payload = _gql_check(r)
                proj = payload.get("data", {}).get(key, {}).get("projectV2")
                if proj:
                    resolved_query = q
                    resolved_key = key
                    proj_data = proj
                    break

            if not proj_data:
                raise RuntimeError(
                    f"Project #{project_number} not found for '{owner}'."
                )

            total_count = proj_data["items"]["totalCount"]
            project_id = proj_data["id"]
            project_title = proj_data["title"]

            # Build a lookup of ALL field definitions on this project.
            all_field_names: list[str] = [
                node["name"]
                for node in proj_data.get("fields", {}).get("nodes", [])
                if node
                and node.get("name")
                and node["name"].lower() not in BUILTIN_FIELDS
            ]

            # Walk cursor pages, collecting items in [offset, offset+limit)
            collected = []
            seen = 0  # total items processed across all pages
            page_items = proj_data["items"]

            while True:
                for node in page_items["nodes"]:
                    if seen >= offset and len(collected) < limit:
                        collected.append(node)
                    seen += 1
                    if len(collected) >= limit:
                        break

                if len(collected) >= limit:
                    break

                pi = page_items["pageInfo"]
                if not pi["hasNextPage"]:
                    break

                # Fetch next page
                r = await client.post(
                    GRAPHQL_URL,
                    headers=_gql_headers(),
                    json={
                        "query": resolved_query,
                        "variables": {
                            "login": owner,
                            "number": project_number,
                            "first": PAGE_SIZE,
                            "after": pi["endCursor"],
                        },
                    },
                )
                payload = _gql_check(r)
                proj_page = (
                    payload.get("data", {}).get(resolved_key, {}).get("projectV2")
                )
                if not proj_page:
                    break
                page_items = proj_page["items"]

        items = []
        for node in collected:
            cnt = node.get("content") or {}
            fields = _parse_fv((node.get("fieldValues") or {}).get("nodes", []))
            status = fields.pop("Status", None)

            # Build custom_fields with ALL project fields — null for any not yet set
            custom_fields = {name: fields.get(name, None) for name in all_field_names}

            items.append(
                {
                    "item_id": node["id"],
                    "type": node["type"],
                    "title": cnt.get("title", "(no title)"),
                    "status": status,
                    "custom_fields": custom_fields,
                    "number": cnt.get("number"),
                    "state": cnt.get("state"),
                    "url": cnt.get("url"),
                    "body": (cnt.get("body") or "")[:300] or None,
                    "assignees": [
                        a["login"]
                        for a in (cnt.get("assignees") or {}).get("nodes", [])
                    ],
                    "labels": [
                        {"name": lb["name"], "color": "#" + lb["color"]}
                        for lb in (cnt.get("labels") or {}).get("nodes", [])
                    ],
                    "created_at": cnt.get("createdAt"),
                    "updated_at": cnt.get("updatedAt"),
                }
            )

        logger.info(
            f"list_project_tasks | returned {len(items)} of {total_count} "
            f"(offset={offset})"
        )
        return {
            "project_title": project_title,
            "project_id": project_id,
            "total_items": total_count,
            "offset": offset,
            "returned_items": len(items),
            "custom_field_names": all_field_names,
            "items": items,
        }
