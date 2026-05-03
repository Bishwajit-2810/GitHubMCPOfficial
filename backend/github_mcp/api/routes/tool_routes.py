"""HTTP routes that wrap MCP tools, with Firebase auth + permission gates."""

from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from loguru import logger

from ..crypto import decrypt_token
from ..db import get_db_dep
from ..dependencies import (
    get_current_user,
    require_repo_read,
    require_repo_write,
    require_project_scope,
)
from ..models import OAuthConnection, User, UserContext

router = APIRouter(prefix="/tools", tags=["tools"])


# ── Helpers ──────────────────────────────────────────────────────────────────

def _ctx_defaults(user: User, db: Session) -> dict:
    """Return owner/repo/project_number from user context, or empty strings."""
    ctx = db.query(UserContext).filter_by(user_id=user.id).first()
    if not ctx:
        return {"owner": None, "repo": None, "project_number": None}
    return {
        "owner": ctx.selected_owner,
        "repo": ctx.selected_repo,
        "project_number": ctx.selected_project_number,
    }


def _token(conn: OAuthConnection) -> str:
    return decrypt_token(conn.access_token_encrypted)


def _require_owner_repo(owner: str | None, repo: str | None) -> tuple[str, str]:
    """Raise a user-friendly 400 if owner or repo could not be resolved."""
    from ..exceptions import AppError
    if not owner or not repo:
        missing = []
        if not owner:
            missing.append("owner")
        if not repo:
            missing.append("repo")
        raise AppError(
            "MISSING_CONTEXT",
            f"Missing required field(s): {', '.join(missing)}. "
            "Set them in the request body or via POST /api/v1/auth/context.",
            status_code=400,
        )
    return owner, repo


# ── Request models ────────────────────────────────────────────────────────────

class ListFilesRequest(BaseModel):
    path: str = ""
    ref: Optional[str] = None
    owner: Optional[str] = None
    repo: Optional[str] = None


class CreateBranchRequest(BaseModel):
    branch: str
    source_branch: Optional[str] = None
    owner: Optional[str] = None
    repo: Optional[str] = None


class CreateFileRequest(BaseModel):
    path: str
    content: str
    message: str
    branch: Optional[str] = None
    owner: Optional[str] = None
    repo: Optional[str] = None


class CreatePRRequest(BaseModel):
    title: str
    head: str
    base: Optional[str] = None
    body: str = ""
    draft: bool = False
    owner: Optional[str] = None
    repo: Optional[str] = None


class CreateTaskRequest(BaseModel):
    title: str
    body: str = ""
    status: Optional[str] = None
    project_number: Optional[int] = None
    repo: Optional[str] = None
    owner: Optional[str] = None
    assignee: Optional[str] = None
    label: Optional[str] = None


class ListTasksRequest(BaseModel):
    project_number: Optional[int] = None
    owner: Optional[str] = None
    offset: int = 0
    limit: int = 50


class AssignTaskRequest(BaseModel):
    issue_number: int
    assignees: list[str]
    labels: Optional[list[str]] = None
    owner: Optional[str] = None
    repo: Optional[str] = None


class UpdateTaskStatusRequest(BaseModel):
    item_id: str
    status: str
    project_number: Optional[int] = None
    owner: Optional[str] = None


class AskCodebaseRequest(BaseModel):
    question: str
    owner: Optional[str] = None
    repo: Optional[str] = None


class ExploreCodebaseRequest(BaseModel):
    query: str


class CreateProjectFieldRequest(BaseModel):
    field_name: str
    field_type: str  # "text" | "number" | "date"
    project_number: Optional[int] = None
    owner: Optional[str] = None


class SetTaskFieldsRequest(BaseModel):
    item_id: str
    fields: dict
    project_number: Optional[int] = None
    owner: Optional[str] = None


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/list-files")
async def list_files(
    body: ListFilesRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_repo_read),
):
    from github_mcp.tools.files import register_list_files_tool  # noqa: F401 — import side check
    import httpx
    from github_mcp.constants import GITHUB_API
    from github_mcp.core.github_api import _headers, _raise_for_status

    defaults = _ctx_defaults(user, db)
    owner, repo = _require_owner_repo(
        body.owner or defaults["owner"],
        body.repo or defaults["repo"],
    )
    token = _token(conn)
    url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{body.path}"

    logger.info(f"list_files | user={user.id} {owner}/{repo} path={body.path!r}")
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=_headers(token), params={"ref": body.ref} if body.ref else {})
    _raise_for_status(resp)
    raw = resp.json()
    items = raw if isinstance(raw, list) else [raw]
    return {
        "repo": f"{owner}/{repo}",
        "path": body.path or "/",
        "count": len(items),
        "items": [
            {"name": i["name"], "type": i["type"], "size": i.get("size"),
             "sha": i["sha"], "html_url": i.get("html_url")}
            for i in items
        ],
    }


@router.post("/create-branch")
async def create_branch(
    body: CreateBranchRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_repo_write),
):
    import httpx
    from github_mcp.constants import GITHUB_API
    from github_mcp.core.github_api import _headers, _raise_for_status, get_default_branch

    defaults = _ctx_defaults(user, db)
    owner, repo = _require_owner_repo(
        body.owner or defaults["owner"],
        body.repo or defaults["repo"],
    )
    token = _token(conn)

    source = body.source_branch or await get_default_branch(owner, repo, token)
    logger.info(f"create_branch | user={user.id} {owner}/{repo} {source} -> {body.branch}")

    async with httpx.AsyncClient() as client:
        r = await client.get(
            f"{GITHUB_API}/repos/{owner}/{repo}/git/ref/heads/{source}",
            headers=_headers(token),
        )
        _raise_for_status(r)
        sha = r.json()["object"]["sha"]
        cr = await client.post(
            f"{GITHUB_API}/repos/{owner}/{repo}/git/refs",
            headers=_headers(token),
            json={"ref": f"refs/heads/{body.branch}", "sha": sha},
        )
        _raise_for_status(cr)
        data = cr.json()

    return {
        "repo": f"{owner}/{repo}",
        "branch": body.branch,
        "source": source,
        "sha": data["object"]["sha"],
    }


@router.post("/create-file")
async def create_file(
    body: CreateFileRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_repo_write),
):
    import base64
    import httpx
    from github_mcp.constants import GITHUB_API
    from github_mcp.core.github_api import _headers, _raise_for_status

    defaults = _ctx_defaults(user, db)
    owner, repo = _require_owner_repo(
        body.owner or defaults["owner"],
        body.repo or defaults["repo"],
    )
    token = _token(conn)

    logger.info(f"create_file | user={user.id} {owner}/{repo} path={body.path!r}")
    payload: dict = {
        "message": body.message,
        "content": base64.b64encode(body.content.encode()).decode(),
    }
    if body.branch:
        payload["branch"] = body.branch

    async with httpx.AsyncClient() as client:
        # Check if file exists to get sha for update
        check = await client.get(
            f"{GITHUB_API}/repos/{owner}/{repo}/contents/{body.path}",
            headers=_headers(token),
        )
        if check.status_code == 200:
            payload["sha"] = check.json().get("sha")

        resp = await client.put(
            f"{GITHUB_API}/repos/{owner}/{repo}/contents/{body.path}",
            headers=_headers(token),
            json=payload,
        )
        _raise_for_status(resp)
        data = resp.json()

    return {
        "repo": f"{owner}/{repo}",
        "path": body.path,
        "sha": data["content"]["sha"],
        "html_url": data["content"]["html_url"],
        "commit_sha": data["commit"]["sha"],
    }


@router.post("/create-pull-request")
async def create_pull_request(
    body: CreatePRRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_repo_write),
):
    import httpx
    from github_mcp.constants import GITHUB_API
    from github_mcp.core.github_api import _headers, _raise_for_status, get_default_branch

    defaults = _ctx_defaults(user, db)
    owner, repo = _require_owner_repo(
        body.owner or defaults["owner"],
        body.repo or defaults["repo"],
    )
    token = _token(conn)

    base = body.base or await get_default_branch(owner, repo, token)
    logger.info(f"create_pull_request | user={user.id} {owner}/{repo} {body.head} -> {base}")

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{GITHUB_API}/repos/{owner}/{repo}/pulls",
            headers=_headers(token),
            json={"title": body.title, "head": body.head, "base": base,
                  "body": body.body, "draft": body.draft},
        )
    _raise_for_status(resp)
    data = resp.json()
    return {
        "repo": f"{owner}/{repo}",
        "number": data["number"],
        "title": data["title"],
        "state": data["state"],
        "draft": data["draft"],
        "html_url": data["html_url"],
        "head": data["head"]["ref"],
        "base": data["base"]["ref"],
    }


@router.post("/create-task")
async def create_task(
    body: CreateTaskRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_project_scope),
):
    from github_mcp.tools.tasks import register_create_project_task_tool  # noqa
    from github_mcp.config import DEFAULT_OWNER, DEFAULT_REPO, DEFAULT_PROJECT
    import httpx
    from github_mcp.constants import GITHUB_API, GRAPHQL_URL
    from github_mcp.core.github_api import _headers, _gql_headers, _gql_check, _raise_for_status
    from github_mcp.utils.project_helpers import _resolve_project, _find_field

    defaults = _ctx_defaults(user, db)
    owner = body.owner or defaults["owner"] or DEFAULT_OWNER
    repo = body.repo or defaults["repo"] or DEFAULT_REPO
    project_number = body.project_number or defaults["project_number"] or DEFAULT_PROJECT
    token = _token(conn)

    logger.info(f"create_task | user={user.id} {owner} project=#{project_number} title={body.title!r}")

    async with httpx.AsyncClient() as client:
        proj = await _resolve_project(client, owner, project_number)
        project_id = proj["id"]

        status_field_id = status_option_id = None
        if body.status:
            sf = _find_field(proj, "Status")
            status_field_id = sf["id"]
            for opt in sf.get("options", []):
                if opt["name"].lower() == body.status.lower():
                    status_option_id = opt["id"]
                    break

        issue_url = issue_number = None
        if repo:
            issue_payload: dict = {"title": body.title, "body": body.body}
            if body.assignee:
                issue_payload["assignees"] = [body.assignee]
            if body.label:
                issue_payload["labels"] = [body.label]
            ir = await client.post(
                f"{GITHUB_API}/repos/{owner}/{repo}/issues",
                headers=_headers(token),
                json=issue_payload,
            )
            _raise_for_status(ir)
            idata = ir.json()
            issue_url = idata["html_url"]
            issue_number = idata["number"]
            content_id = idata["node_id"]
            add_r = await client.post(GRAPHQL_URL, headers=_gql_headers(token), json={
                "query": "mutation($pid:ID!,$cid:ID!){addProjectV2ItemById(input:{projectId:$pid,contentId:$cid}){item{id}}}",
                "variables": {"pid": project_id, "cid": content_id},
            })
            item_id = _gql_check(add_r)["data"]["addProjectV2ItemById"]["item"]["id"]
        else:
            dr = await client.post(GRAPHQL_URL, headers=_gql_headers(token), json={
                "query": "mutation($pid:ID!,$t:String!,$b:String){addProjectV2DraftIssue(input:{projectId:$pid,title:$t,body:$b}){projectItem{id}}}",
                "variables": {"pid": project_id, "t": body.title, "b": body.body},
            })
            item_id = _gql_check(dr)["data"]["addProjectV2DraftIssue"]["projectItem"]["id"]

        if status_field_id and status_option_id:
            mut = f'mutation{{updateProjectV2ItemFieldValue(input:{{projectId:"{project_id}",itemId:"{item_id}",fieldId:"{status_field_id}",value:{{singleSelectOptionId:"{status_option_id}"}}}})}}'
            st_r = await client.post(GRAPHQL_URL, headers=_gql_headers(token), json={"query": mut})
            _gql_check(st_r)

    result = {"project_id": project_id, "item_id": item_id, "title": body.title, "status": body.status}
    if issue_url:
        result["issue_url"] = issue_url
        result["issue_number"] = issue_number
    return result


@router.post("/list-tasks")
async def list_tasks(
    body: ListTasksRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_project_scope),
):
    from github_mcp.config import DEFAULT_OWNER, DEFAULT_PROJECT

    defaults = _ctx_defaults(user, db)
    owner = body.owner or defaults["owner"] or DEFAULT_OWNER
    project_number = body.project_number or defaults["project_number"] or DEFAULT_PROJECT

    # Reuse the existing MCP tool logic directly
    import httpx
    from github_mcp.tools.task_list import register_list_project_tasks_tool  # noqa

    # Import the core pagination logic inline to avoid re-registering the MCP tool
    from github_mcp.constants import GRAPHQL_URL, PAGE_SIZE, BUILTIN_FIELDS
    from github_mcp.core.github_api import _gql_headers, _gql_check

    token = _token(conn)
    limit = max(1, body.limit)
    offset = body.offset

    _QUERY = """
    query($login:String!,$number:Int!,$first:Int!,$after:String){
      user(login:$login){projectV2(number:$number){
        id title
        fields(first:50){nodes{__typename
          ...on ProjectV2Field{id name dataType}
          ...on ProjectV2SingleSelectField{id name options{id name}}
        }}
        items(first:$first,after:$after){totalCount pageInfo{endCursor hasNextPage}
          nodes{id type
            fieldValues(first:20){nodes{__typename
              ...on ProjectV2ItemFieldSingleSelectValue{name field{...on ProjectV2SingleSelectField{name}}}
              ...on ProjectV2ItemFieldTextValue{text field{...on ProjectV2Field{name}}}
              ...on ProjectV2ItemFieldNumberValue{number field{...on ProjectV2Field{name}}}
              ...on ProjectV2ItemFieldDateValue{date field{...on ProjectV2Field{name}}}
            }}
            content{
              ...on Issue{number title state url body assignees(first:5){nodes{login}} labels(first:10){nodes{name color}} createdAt updatedAt}
              ...on DraftIssue{title body assignees(first:5){nodes{login}} createdAt:updatedAt}
            }
          }
        }
      }}
    }"""
    _ORG_QUERY = _QUERY.replace("user(login:$login)", "organization(login:$login)")

    def _parse_fv(nodes):
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
        resolved_query = resolved_key = proj_data = None
        for q, key in ((_QUERY, "user"), (_ORG_QUERY, "organization")):
            r = await client.post(GRAPHQL_URL, headers=_gql_headers(token), json={
                "query": q, "variables": {"login": owner, "number": project_number, "first": PAGE_SIZE, "after": None}
            })
            payload = _gql_check(r)
            proj = payload.get("data", {}).get(key, {}).get("projectV2")
            if proj:
                resolved_query, resolved_key, proj_data = q, key, proj
                break

        if not proj_data:
            from ..exceptions import NotFoundError
            raise NotFoundError(f"Project #{project_number} not found for '{owner}'")

        total_count = proj_data["items"]["totalCount"]
        all_field_names = [
            n["name"] for n in proj_data.get("fields", {}).get("nodes", [])
            if n and n.get("name") and n["name"].lower() not in BUILTIN_FIELDS
        ]

        collected, seen, page_items = [], 0, proj_data["items"]
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
            r = await client.post(GRAPHQL_URL, headers=_gql_headers(token), json={
                "query": resolved_query,
                "variables": {"login": owner, "number": project_number, "first": PAGE_SIZE, "after": pi["endCursor"]},
            })
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
        custom_fields = {name: fields.get(name, None) for name in all_field_names}
        items.append({
            "item_id": node["id"], "type": node["type"],
            "title": cnt.get("title", "(no title)"), "status": status,
            "custom_fields": custom_fields, "number": cnt.get("number"),
            "state": cnt.get("state"), "url": cnt.get("url"),
            "assignees": [a["login"] for a in (cnt.get("assignees") or {}).get("nodes", [])],
            "labels": [{"name": lb["name"], "color": "#" + lb["color"]} for lb in (cnt.get("labels") or {}).get("nodes", [])],
            "created_at": cnt.get("createdAt"), "updated_at": cnt.get("updatedAt"),
        })

    return {"project_id": proj_data["id"], "total_items": total_count,
            "offset": offset, "returned_items": len(items), "items": items}


@router.post("/assign-task")
async def assign_task(
    body: AssignTaskRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_repo_write),
):
    import httpx
    from github_mcp.constants import GITHUB_API
    from github_mcp.core.github_api import _headers, _raise_for_status
    import random

    defaults = _ctx_defaults(user, db)
    owner, repo = _require_owner_repo(
        body.owner or defaults["owner"],
        body.repo or defaults["repo"],
    )
    token = _token(conn)
    issue_api = f"{GITHUB_API}/repos/{owner}/{repo}/issues/{body.issue_number}"

    async with httpx.AsyncClient() as client:
        cur = await client.get(issue_api, headers=_headers(token))
        _raise_for_status(cur)
        existing_labels = [lb["name"] for lb in cur.json().get("labels", [])]

        if body.labels:
            rl = await client.get(f"{GITHUB_API}/repos/{owner}/{repo}/labels", headers=_headers(token), params={"per_page": 100})
            _raise_for_status(rl)
            repo_labels = {lb["name"] for lb in rl.json()}
            for lbl in body.labels:
                if lbl not in repo_labels:
                    color = f"{random.randint(0, 0xFFFFFF):06x}"
                    await client.post(f"{GITHUB_API}/repos/{owner}/{repo}/labels", headers=_headers(token), json={"name": lbl, "color": color})

        merged = list(dict.fromkeys(existing_labels + (body.labels or [])))
        patch: dict = {"assignees": body.assignees}
        if body.labels is not None:
            patch["labels"] = merged

        pr = await client.patch(issue_api, headers=_headers(token), json=patch)
        _raise_for_status(pr)
        data = pr.json()

    return {
        "repo": f"{owner}/{repo}", "issue_number": data["number"],
        "title": data["title"], "state": data["state"],
        "assignees": [a["login"] for a in data.get("assignees", [])],
        "labels": [lb["name"] for lb in data.get("labels", [])],
    }


@router.post("/update-task-status")
async def update_task_status(
    body: UpdateTaskStatusRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_project_scope),
):
    import httpx
    from github_mcp.constants import GRAPHQL_URL
    from github_mcp.core.github_api import _gql_headers, _gql_check
    from github_mcp.utils.project_helpers import _resolve_project, _find_field
    from github_mcp.config import DEFAULT_OWNER, DEFAULT_PROJECT

    defaults = _ctx_defaults(user, db)
    owner = body.owner or defaults["owner"] or DEFAULT_OWNER
    project_number = body.project_number or defaults["project_number"] or DEFAULT_PROJECT
    token = _token(conn)

    if not body.item_id or not body.item_id.startswith("PVTI_"):
        from ..exceptions import AppError
        raise AppError("INVALID_ITEM_ID", "item_id must start with PVTI_", status_code=422)

    async with httpx.AsyncClient() as client:
        proj = await _resolve_project(client, owner, project_number)
        project_id = proj["id"]
        sf = _find_field(proj, "Status")
        status_option_id = next(
            (o["id"] for o in sf.get("options", []) if o["name"].lower() == body.status.lower()),
            None,
        )
        if not status_option_id:
            available = [o["name"] for o in sf.get("options", [])]
            from ..exceptions import AppError
            raise AppError("STATUS_NOT_FOUND", f"Status '{body.status}' not found. Available: {available}", status_code=422)

        mut = f'mutation{{updateProjectV2ItemFieldValue(input:{{projectId:"{project_id}",itemId:"{body.item_id}",fieldId:"{sf["id"]}",value:{{singleSelectOptionId:"{status_option_id}"}}}})}}'
        r = await client.post(GRAPHQL_URL, headers=_gql_headers(token), json={"query": mut})
        _gql_check(r)

    return {"item_id": body.item_id, "status_updated": body.status}


@router.post("/ask-codebase")
async def ask_codebase(
    body: AskCodebaseRequest,
    user: User = Depends(get_current_user),
):
    """RAG Q&A over the indexed repository (requires ingest.py to have run)."""
    import os

    logger.info(f"ask_codebase | user={user.id} question={body.question[:80]!r}")

    groq_key = os.environ.get("GROQ_API_KEY", "")
    if not groq_key:
        from ..exceptions import AppError
        raise AppError("CONFIG_ERROR", "GROQ_API_KEY not configured", status_code=500)

    from github_mcp.tools.rag_query import _build_ask_chain, _get_retriever

    chain = _build_ask_chain()
    answer = await chain.ainvoke(body.question)
    docs = _get_retriever().invoke(body.question)
    sources = list(dict.fromkeys(
        d.metadata.get("filename") or d.metadata.get("source", "unknown").split("/")[-1]
        for d in docs
    ))
    return {"question": body.question, "answer": answer, "sources": sources}


@router.post("/explore-codebase")
async def explore_codebase(
    body: ExploreCodebaseRequest,
    user: User = Depends(get_current_user),
):
    """File-level explorer over the indexed repository."""
    import os

    logger.info(f"explore_codebase | user={user.id} query={body.query[:80]!r}")

    groq_key = os.environ.get("GROQ_API_KEY", "")
    if not groq_key:
        from ..exceptions import AppError
        raise AppError("CONFIG_ERROR", "GROQ_API_KEY not configured", status_code=500)

    from github_mcp.tools.rag_query import _build_file_index, _get_retriever, _EXPLORE_PROMPT, _format_docs
    from collections import defaultdict

    file_index = _build_file_index()
    total_files = len(file_index)

    ext_counter: dict = defaultdict(int)
    for info in file_index.values():
        ext_counter[info["extension"] or "(no ext)"] += 1
    file_summary = dict(sorted(ext_counter.items()))

    all_images = [
        {"filename": info["filename"], "folder": info["folder"], "url": info["url"]}
        for info in file_index.values()
        if info["file_type"] == "image"
    ]

    docs = _get_retriever().invoke(body.query)
    context_str = _format_docs(docs)

    from langchain_groq import ChatGroq
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_core.output_parsers import StrOutputParser

    llm = ChatGroq(model="openai/gpt-oss-120b", temperature=0)
    prompt = ChatPromptTemplate.from_template(_EXPLORE_PROMPT)
    chain = prompt | llm | StrOutputParser()
    answer = await chain.ainvoke({"context": context_str, "question": body.query})

    return {
        "query": body.query,
        "answer": answer,
        "total_files": total_files,
        "file_summary": file_summary,
        "images": all_images,
    }


@router.post("/create-project-field")
async def create_project_field(
    body: CreateProjectFieldRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_project_scope),
):
    import httpx
    from github_mcp.constants import GRAPHQL_URL
    from github_mcp.core.github_api import _gql_headers, _gql_check
    from github_mcp.utils.project_helpers import _resolve_project
    from github_mcp.config import DEFAULT_OWNER, DEFAULT_PROJECT

    defaults = _ctx_defaults(user, db)
    owner = body.owner or defaults["owner"] or DEFAULT_OWNER
    project_number = body.project_number or defaults["project_number"] or DEFAULT_PROJECT
    token = _token(conn)

    TYPE_MAP = {"text": "TEXT", "number": "NUMBER", "date": "DATE"}
    gql_type = TYPE_MAP.get(body.field_type.lower())
    if not gql_type:
        from ..exceptions import AppError
        raise AppError("INVALID_TYPE", f"field_type must be one of: text, number, date", status_code=422)

    async with httpx.AsyncClient() as client:
        proj = await _resolve_project(client, owner, project_number)
        project_id = proj["id"]

        existing = next(
            (f for f in proj.get("fields", {}).get("nodes", []) or []
             if f and f.get("name", "").lower() == body.field_name.lower()),
            None,
        )
        if existing:
            return {"project_id": project_id, "field_id": existing["id"],
                    "field_name": existing["name"], "field_type": body.field_type, "created": False}

        mut = """mutation($pid:ID!,$name:String!,$dt:ProjectV2CustomFieldType!){
          createProjectV2Field(input:{projectId:$pid,name:$name,dataType:$dt}){
            projectV2Field{...on ProjectV2Field{id name dataType}}
          }
        }"""
        r = await client.post(GRAPHQL_URL, headers=_gql_headers(token), json={
            "query": mut, "variables": {"pid": project_id, "name": body.field_name, "dt": gql_type},
        })
        data = _gql_check(r)
        field = data["data"]["createProjectV2Field"]["projectV2Field"]

    return {"project_id": project_id, "field_id": field["id"],
            "field_name": field["name"], "field_type": body.field_type, "created": True}


@router.post("/set-task-fields")
async def set_task_fields(
    body: SetTaskFieldsRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
    conn: OAuthConnection = Depends(require_project_scope),
):
    import httpx
    from github_mcp.constants import GRAPHQL_URL
    from github_mcp.core.github_api import _gql_headers, _gql_check
    from github_mcp.utils.project_helpers import _resolve_project, _inline_value
    from github_mcp.config import DEFAULT_OWNER, DEFAULT_PROJECT

    if not body.item_id or not body.item_id.startswith("PVTI_"):
        from ..exceptions import AppError
        raise AppError("INVALID_ITEM_ID", "item_id must start with PVTI_", status_code=422)

    defaults = _ctx_defaults(user, db)
    owner = body.owner or defaults["owner"] or DEFAULT_OWNER
    project_number = body.project_number or defaults["project_number"] or DEFAULT_PROJECT
    token = _token(conn)

    async with httpx.AsyncClient() as client:
        proj = await _resolve_project(client, owner, project_number)
        project_id = proj["id"]

        field_nodes = [f for f in (proj.get("fields", {}).get("nodes", []) or []) if f]
        field_map = {f["name"].lower(): f for f in field_nodes if f.get("name")}

        invalid = [k for k in body.fields if k.lower() not in field_map]
        if invalid:
            from ..exceptions import AppError
            valid_names = [f["name"] for f in field_nodes if f.get("name")]
            raise AppError("INVALID_FIELDS", f"Unknown fields: {invalid}. Valid: {valid_names}", status_code=422)

        updated = []
        for field_name, value in body.fields.items():
            field = field_map[field_name.lower()]
            field_id = field["id"]
            data_type = field.get("dataType", "TEXT")
            val_input = _inline_value(data_type, value)
            mut = f'mutation{{updateProjectV2ItemFieldValue(input:{{projectId:"{project_id}",itemId:"{body.item_id}",fieldId:"{field_id}",value:{{{val_input}}}}})}}'
            r = await client.post(GRAPHQL_URL, headers=_gql_headers(token), json={"query": mut})
            _gql_check(r)
            updated.append(field_name)

    return {"item_id": body.item_id, "updated_fields": updated}
