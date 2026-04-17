"""Project-specific helper functions.

Provides utilities for working with GitHub Projects v2.
"""

import re
import httpx
from loguru import logger
from ..constants import (
    GRAPHQL_URL,
    USER_PROJECT_QUERY,
    ORG_PROJECT_QUERY,
)
from ..core.github_api import _gql_headers, _gql_check


async def _resolve_project(
    client: httpx.AsyncClient, owner: str, project_number: int
) -> dict:
    """Return the projectV2 node (with fields) for the given owner + number."""
    variables = {"login": owner, "number": project_number}
    for query, key in (
        (USER_PROJECT_QUERY, "user"),
        (ORG_PROJECT_QUERY, "organization"),
    ):
        r = await client.post(
            GRAPHQL_URL,
            headers=_gql_headers(),
            json={"query": query, "variables": variables},
        )
        payload = _gql_check(r)
        proj = payload.get("data", {}).get(key, {}).get("projectV2")
        if proj:
            return proj

    raise RuntimeError(
        f"Project #{project_number} not found for '{owner}'. "
        "Check PROJECT_ID and that the token has the 'project' scope."
    )


def _find_field(proj: dict, name: str) -> dict:
    """Return the field node matching `name` (case-insensitive)."""
    for node in proj.get("fields", {}).get("nodes", []):
        if node and node.get("name", "").lower() == name.lower():
            return node
    available = [
        n["name"]
        for n in proj.get("fields", {}).get("nodes", [])
        if n and n.get("name")
    ]
    raise RuntimeError(
        f"Field '{name}' not found on this project. Available: {available}"
    )


def _inline_value(data_type: str, value) -> str:
    """
    Build the inline value: {...} block for updateProjectV2ItemFieldValue.

    Must be inlined — GitHub GraphQL rejects ProjectV2FieldValue as a variable.

    Type detection order:
      1. Trust data_type metadata if DATE or NUMBER
      2. Auto-detect from value: YYYY-MM-DD -> date, pure number -> number
      3. Fall back to text
    This ensures correct format even when API returns empty/wrong dataType.
    """
    dt = (data_type or "").upper()
    str_val = str(value).strip()

    # 1. Trust explicit metadata
    if dt == "DATE":
        return '{ date: "' + str_val + '" }'
    if dt == "NUMBER":
        return "{ number: " + str(float(str_val)) + " }"

    # 2. Auto-detect: YYYY-MM-DD
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", str_val):
        logger.debug(f"_inline_value | auto DATE {str_val!r} (meta={dt!r})")
        return '{ date: "' + str_val + '" }'

    # 3. Auto-detect: pure number
    try:
        num = float(str_val)
        if re.fullmatch(r"-?\d+(\.\d+)?", str_val):
            logger.debug(f"_inline_value | auto NUMBER {str_val!r} (meta={dt!r})")
            return "{ number: " + str(num) + " }"
    except (ValueError, TypeError):
        pass

    # 4. Text
    safe = str_val.replace("\\", "\\\\").replace('"', '\\"')
    return '{ text: "' + safe + '" }'
