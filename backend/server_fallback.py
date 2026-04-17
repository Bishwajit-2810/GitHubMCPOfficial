import os
import base64
from typing import Optional

import httpx
from dotenv import load_dotenv
from loguru import logger
from fastmcp import FastMCP

load_dotenv()

mcp = FastMCP("github-mcp")

GITHUB_API = "https://api.github.com"
GRAPHQL_URL = "https://api.github.com/graphql"

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
DEFAULT_OWNER = os.environ.get("GITHUB_OWNER", "")
DEFAULT_REPO = os.environ.get("GITHUB_REPO", "")
DEFAULT_PROJECT = int(os.environ.get("PROJECT_ID", "0"))


# ============================================================
# Shared helpers
# ============================================================


def _headers() -> dict:
    if not GITHUB_TOKEN:
        raise RuntimeError("GITHUB_TOKEN is not set. Add it to your .env file.")
    return {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def _gql_headers() -> dict:
    return {**_headers(), "Content-Type": "application/json"}


def _raise_for_status(resp: httpx.Response) -> None:
    if resp.status_code >= 400:
        try:
            detail = resp.json()
        except Exception:
            detail = resp.text
        logger.error(f"GitHub API {resp.status_code}: {detail}")
        raise RuntimeError(f"GitHub API error {resp.status_code}: {detail}")


def _gql_check(resp: httpx.Response) -> dict:
    """Raise on HTTP errors AND on GraphQL-level errors. Return parsed JSON."""
    _raise_for_status(resp)
    payload = resp.json()
    errs = payload.get("errors")
    if errs:
        msg = "; ".join(e.get("message", str(e)) for e in errs)
        logger.error(f"GraphQL error: {msg}")
        raise RuntimeError(f"GraphQL error: {msg}")
    return payload


_PROJECT_FIELDS_FRAGMENT = """
  id title
  fields(first: 50) {
    nodes {
      __typename
      ... on ProjectV2Field           { id name dataType }
      ... on ProjectV2SingleSelectField {
        id name
        options { id name }
      }
      ... on ProjectV2IterationField  { id name }
    }
  }
"""

_USER_PROJECT_QUERY = (
    """
query($login: String!, $number: Int!) {
  user(login: $login) {
    projectV2(number: $number) {
      """
    + _PROJECT_FIELDS_FRAGMENT
    + """
    }
  }
}
"""
)

_ORG_PROJECT_QUERY = (
    """
query($login: String!, $number: Int!) {
  organization(login: $login) {
    projectV2(number: $number) {
      """
    + _PROJECT_FIELDS_FRAGMENT
    + """
    }
  }
}
"""
)


async def _resolve_project(
    client: httpx.AsyncClient, owner: str, project_number: int
) -> dict:
    """Return the projectV2 node (with fields) for the given owner + number."""
    variables = {"login": owner, "number": project_number}
    for query, key in (
        (_USER_PROJECT_QUERY, "user"),
        (_ORG_PROJECT_QUERY, "organization"),
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
    import re as _re

    dt = (data_type or "").upper()
    str_val = str(value).strip()

    # 1. Trust explicit metadata
    if dt == "DATE":
        return '{ date: "' + str_val + '" }'
    if dt == "NUMBER":
        return "{ number: " + str(float(str_val)) + " }"

    # 2. Auto-detect: YYYY-MM-DD
    if _re.fullmatch(r"\d{4}-\d{2}-\d{2}", str_val):
        logger.debug(f"_inline_value | auto DATE {str_val!r} (meta={dt!r})")
        return '{ date: "' + str_val + '" }'

    # 3. Auto-detect: pure number
    try:
        num = float(str_val)
        if _re.fullmatch(r"-?\d+(\.\d+)?", str_val):
            logger.debug(f"_inline_value | auto NUMBER {str_val!r} (meta={dt!r})")
            return "{ number: " + str(num) + " }"
    except (ValueError, TypeError):
        pass

    # 4. Text
    safe = str_val.replace("\\", "\\\\").replace('"', '\\"')
    return '{ text: "' + safe + '" }'


# ============================================================
# Tool 1 List files
# ============================================================
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


# ============================================================
# Tool 2 Create a branch
# ============================================================
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


# ============================================================
# Tool 3 Create / update a file
# ============================================================
@mcp.tool()
async def create_file(
    file_path: str,
    content: str,
    commit_message: str,
    branch: str = "main",
    owner: Optional[str] = None,
    repo: Optional[str] = None,
) -> dict:
    """
    Create or update a file in a GitHub repository.

    Args:
        file_path:      Path inside the repo e.g. "src/hello.py".
        content:        Plain-text content for the file.
        commit_message: Git commit message.
        branch:         Target branch (default "main").
        owner:          Repo owner (defaults to GITHUB_OWNER in .env).
        repo:           Repository name (defaults to GITHUB_REPO in .env).
    """
    owner = owner or DEFAULT_OWNER
    repo = repo or DEFAULT_REPO

    logger.info(f"create_file | {owner}/{repo} | {file_path} on {branch}")
    b64 = base64.b64encode(content.encode()).decode()
    url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{file_path}"
    payload: dict = {"message": commit_message, "content": b64, "branch": branch}

    async with httpx.AsyncClient() as client:
        ex = await client.get(url, headers=_headers(), params={"ref": branch})
        if ex.status_code == 200:
            payload["sha"] = ex.json()["sha"]
        resp = await client.put(url, headers=_headers(), json=payload)
    _raise_for_status(resp)

    data = resp.json()
    action = "updated" if "sha" in payload else "created"
    logger.info(f"create_file | {action} {file_path}")
    return {
        "repo": f"{owner}/{repo}",
        "action": action,
        "file_path": file_path,
        "branch": branch,
        "commit_sha": data["commit"]["sha"],
        "commit_url": data["commit"]["html_url"],
        "blob_url": data["content"]["html_url"],
    }


# ============================================================
# Tool 4 Create a pull request
# ============================================================
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


# ============================================================
# Tool 5 Create a project task
# ============================================================
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
        logger.info(f"create_project_task | project='{project_title}' id={project_id}")

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


# ============================================================
# Tool 6 List project tasks with offset pagination
# ============================================================
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
    PAGE_SIZE = 100

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
            raise RuntimeError(f"Project #{project_number} not found for '{owner}'.")

        total_count = proj_data["items"]["totalCount"]
        project_id = proj_data["id"]
        project_title = proj_data["title"]

        # Build a lookup of ALL field definitions on this project.
        # We use this to show every field on every item — even empty ones (null).
        # Excludes built-in fields: Title, Assignees, Labels, etc.
        BUILTIN = {
            "title",
            "assignees",
            "labels",
            "linked pull requests",
            "milestone",
            "repository",
            "reviewers",
            "status",
        }
        all_field_names: list[str] = [
            node["name"]
            for node in proj_data.get("fields", {}).get("nodes", [])
            if node and node.get("name") and node["name"].lower() not in BUILTIN
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
            proj_page = payload.get("data", {}).get(resolved_key, {}).get("projectV2")
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
                    a["login"] for a in (cnt.get("assignees") or {}).get("nodes", [])
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


# ============================================================
# Tool 7 Assign users + labels to an existing issue
# ============================================================
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


# ============================================================
# Tool 8 Update the Status of an existing project task
# ============================================================
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
            raise RuntimeError(f"Status '{status}' not found. Available: {available}")

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


# ============================================================
# Tool 9 Create a custom field on a Projects v2 board
# ============================================================
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
        # dataType enum must be inlined (not passed as variable) to avoid
        # schema coercion issues with ProjectV2CustomFieldType
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

    logger.info(f"create_project_field | created '{field_name}' id={fd.get('id')} ✓")
    return {
        "project_id": project_id,
        "field_id": fd.get("id"),
        "field_name": fd.get("name"),
        "field_type": fd.get("dataType"),
        "already_existed": False,
    }


# ============================================================
# Tool 10 - Set field values on a task (dates, numbers, text)
# ============================================================
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
        # ProjectV2SingleSelectField has no dataType attribute — infer from __typename.
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
        # Fail loudly with exact available names so the caller can fix and retry.
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
            # GitHub GraphQL does not accept ProjectV2FieldValue as a variable
            # (it is a union input type and cannot be typed in variables).
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
            logger.info(f"set_task_fields | ✓ '{field_name}' ({data_type}) = {value!r}")

    logger.info(
        f"set_task_fields | done — {len(results)} field(s) updated on {item_id}"
    )
    return {
        "item_id": item_id,
        "project_id": project_id,
        "fields_set": results,
        "available_field_names": available_names,
    }


# ============================================================
# Entry point
# ============================================================
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="GitHub FastMCP server")
    parser.add_argument(
        "--port", type=int, default=8090, help="SSE port (default 8090)"
    )
    parser.add_argument("--host", default="0.0.0.0", help="Bind host (default 0.0.0.0)")
    args = parser.parse_args()

    logger.info(f"GitHub MCP server starting → http://{args.host}:{args.port}/sse")
    logger.info(f"Token   : {'loaded' if GITHUB_TOKEN else 'MISSING'}")
    logger.info(f"Owner   : {DEFAULT_OWNER   or 'MISSING'}")
    logger.info(f"Repo    : {DEFAULT_REPO    or 'MISSING'}")
    logger.info(f"Project : {DEFAULT_PROJECT or 'MISSING'}")

    mcp.run(transport="sse", host=args.host, port=args.port)
