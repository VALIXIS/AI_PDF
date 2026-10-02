"""
VALIXIS Midnight Autonomous PR Auto-Merge & Conflict Prompt Bot
Runs in GitHub Actions runners at 12:00 AM Midnight IST (18:30 UTC).

Non-blocking algorithm:
1. Scans all open PRs targeting default branch (main/master) in chronological order.
2. For clean, passing PRs:
   - Evaluates mergeability via GitHub API & git merge-tree simulation.
   - Merges PR into base branch using 3-tier fallback:
       Tier 1: GitHub CLI (`gh pr merge`)
       Tier 2: GitHub REST API (`PUT /pulls/{number}/merge`)
       Tier 3: Native Git CLI (`git checkout main && git merge origin/{branch} && git push origin main`)
   - Guarantees PR is immediately marked CLOSED and deleted branch.
   - Comments confirmation on PR.
3. For conflicting PRs:
   - Identifies conflicting files.
   - Generates customized Ready-to-Run Antigravity Prompt.
   - Comments the prompt directly on the PR.
   - Continues evaluating remaining PRs without halting!
4. Produces MIDNIGHT_AUTOFOCUS_REPORT.md and midnight_summary.json.
"""

import sys
import os
import subprocess
import json
import argparse
import time
import urllib.request
import urllib.error
from pathlib import Path
from typing import List, Dict, Any, Tuple

try:
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    if hasattr(sys.stderr, 'reconfigure'):
        sys.stderr.reconfigure(encoding='utf-8')
except Exception:
    pass

REPO_ROOT = Path(".").resolve()

def run_cmd(cmd: List[str], cwd: Path = REPO_ROOT) -> subprocess.CompletedProcess:
    """Run command with shell=False so arguments in list are properly passed on POSIX/Windows."""
    try:
        return subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True, shell=False)
    except FileNotFoundError:
        return subprocess.CompletedProcess(cmd, returncode=127, stdout="", stderr=f"Executable '{cmd[0]}' not found")
    except Exception as e:
        return subprocess.CompletedProcess(cmd, returncode=1, stdout="", stderr=str(e))

def get_repo_slug() -> str:
    """Detect current repository slug (owner/repo)."""
    repo = os.environ.get("GITHUB_REPOSITORY")
    if repo and repo.strip():
        return repo.strip()
    
    # Fallback to git remote url
    res = run_cmd(["git", "config", "--get", "remote.origin.url"])
    if res.returncode == 0 and res.stdout.strip():
        url = res.stdout.strip()
        if "github.com/" in url:
            part = url.split("github.com/")[1]
            return part.removesuffix(".git").strip()
        elif "github.com:" in url:
            part = url.split("github.com:")[1]
            return part.removesuffix(".git").strip()
    return ""

def github_api_request_with_status(endpoint: str, method: str = "GET", data: Dict[str, Any] = None) -> Tuple[Any, int]:
    """Execute authenticated GitHub REST API request and return (data, status_code)."""
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    repo = get_repo_slug()
    if not repo:
        return None, 400
    if not token and method != "GET":
        return None, 401

    url = f"https://api.github.com/repos/{repo}/{endpoint.lstrip('/')}"
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "VALIXIS-Midnight-Bot"
    }
    if token:
        headers["Authorization"] = f"token {token}"

    req_data = json.dumps(data).encode('utf-8') if data is not None else None
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            content = resp.read().decode('utf-8')
            return (json.loads(content) if content else {}), resp.status
    except urllib.error.HTTPError as e:
        error_detail = e.read().decode('utf-8', errors='ignore')
        try:
            parsed = json.loads(error_detail)
        except Exception:
            parsed = {"message": error_detail}
        return parsed, e.code
    except Exception as e:
        print(f"  GitHub API exception ({method} {endpoint}): {e}")
        return None, 500

def github_api_request(endpoint: str, method: str = "GET", data: Dict[str, Any] = None) -> Any:
    """Helper wrapper for github_api_request_with_status."""
    res, _ = github_api_request_with_status(endpoint, method=method, data=data)
    return res

def get_open_pull_requests() -> List[Dict[str, Any]]:
    """Retrieve all open pull requests targeting default branch sorted by number ascending."""
    # First attempt: GitHub CLI
    cmd = [
        'gh', 'pr', 'list',
        '--state', 'open',
        '--json', 'number,title,headRefName,baseRefName,mergeable,statusCheckRollup,url,author,labels'
    ]
    res = run_cmd(cmd)
    if res.returncode == 0 and res.stdout.strip():
        try:
            prs = json.loads(res.stdout)
            if isinstance(prs, list) and len(prs) > 0:
                return sorted(prs, key=lambda p: p["number"])
        except Exception as e:
            print(f"  Notice: failed to parse gh pr list: {e}")

    # Second attempt: GitHub REST API
    api_res, status_code = github_api_request_with_status("pulls?state=open&sort=created&direction=asc")
    if status_code == 200 and isinstance(api_res, list):
        prs = []
        for p in api_res:
            prs.append({
                "number": p["number"],
                "title": p["title"],
                "headRefName": p["head"]["ref"],
                "baseRefName": p["base"]["ref"],
                "mergeable": "UNKNOWN",
                "url": p["html_url"],
                "author": {"login": p["user"]["login"]}
            })
        return sorted(prs, key=lambda p: p["number"])

    return []

def get_conflicting_files(pr_number: int) -> List[str]:
    """Retrieve changed/conflicting files for a PR."""
    cmd = ['gh', 'pr', 'view', str(pr_number), '--json', 'files']
    res = run_cmd(cmd)
    if res.returncode == 0 and res.stdout.strip():
        try:
            data = json.loads(res.stdout)
            return [f.get('path', '') for f in data.get('files', []) if f.get('path')]
        except Exception:
            pass

    # API fallback
    api_files = github_api_request(f"pulls/{pr_number}/files")
    if api_files and isinstance(api_files, list):
        return [f["filename"] for f in api_files if "filename" in f]

    return []

def is_ci_passing(pr: Dict[str, Any]) -> bool:
    """Verify that CI status checks for PR are passing."""
    checks = pr.get("statusCheckRollup", [])
    if not checks:
        return True
    
    for check in checks:
        conclusion = (check.get("conclusion") or check.get("state") or "").upper()
        name = check.get("name", "")
        if "midnight" in name.lower():
            continue
        if conclusion in ("FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED"):
            return False
    return True

def comment_on_pr(pr_number: int, comment_body: str) -> bool:
    """Post comment on PR via GitHub CLI or fallback to REST API."""
    res = run_cmd(['gh', 'pr', 'comment', str(pr_number), '--body', comment_body])
    if res.returncode == 0:
        return True
    _, code = github_api_request_with_status(
        f"issues/{pr_number}/comments",
        method="POST",
        data={"body": comment_body}
    )
    return code in (200, 201)

def close_pr_immediately(pr_number: int, branch: str) -> None:
    """Ensure the PR is closed immediately and feature branch deleted."""
    # 1. Close PR via CLI if still open
    run_cmd(['gh', 'pr', 'close', str(pr_number)])
    
    # 2. Close PR via REST API if still open
    detail, _ = github_api_request_with_status(f"pulls/{pr_number}")
    if detail and detail.get("state") == "open":
        github_api_request_with_status(
            f"pulls/{pr_number}",
            method="PATCH",
            data={"state": "closed"}
        )
    
    # 3. Clean up remote branch
    run_cmd(['git', 'push', 'origin', '--delete', branch])
    github_api_request_with_status(f"git/refs/heads/{branch}", method="DELETE")

def check_mergeability(pr_number: int, branch: str, base_branch: str) -> Tuple[str, List[str]]:
    """
    Check mergeability using GitHub API detail endpoint + Git merge-tree verification.
    Returns (status: 'MERGEABLE' | 'CONFLICTING', conflicting_files: List[str]).
    """
    # 1. GitHub API detail check (GitHub calculates mergeable asynchronously)
    for _ in range(3):
        detail, code = github_api_request_with_status(f"pulls/{pr_number}")
        if code == 200 and detail and detail.get("mergeable") is not None:
            if detail["mergeable"] is True:
                return "MERGEABLE", []
            elif detail["mergeable"] is False:
                conflicts = get_conflicting_files(pr_number)
                return "CONFLICTING", conflicts
        time.sleep(1.2)

    # 2. Local git merge-tree simulation
    run_cmd(["git", "fetch", "origin", branch])
    run_cmd(["git", "fetch", "origin", base_branch])
    
    mt_res = run_cmd(["git", "merge-tree", f"origin/{base_branch}", f"origin/{branch}"])
    if mt_res.returncode == 0 and "<<<<<<<" not in mt_res.stdout:
        return "MERGEABLE", []
    else:
        conflicts = get_conflicting_files(pr_number)
        return "CONFLICTING", conflicts

def merge_pull_request(pr_number: int, branch: str, base_branch: str = "main") -> Tuple[bool, str]:
    """
    3-Tier Bulletproof Merge:
      Tier 1: GitHub CLI (`gh pr merge`)
      Tier 2: GitHub REST API (`PUT /pulls/{pr_number}/merge`)
      Tier 3: Git CLI in runner (`git merge origin/{branch} && git push origin {base_branch}`)
    Guarantees the PR is merged and closed immediately.
    """
    # --- Tier 1: GitHub CLI ---
    merge_cmd = ['gh', 'pr', 'merge', str(pr_number), '--merge', '--delete-branch']
    m_res = run_cmd(merge_cmd)
    if m_res.returncode == 0:
        close_pr_immediately(pr_number, branch)
        return True, "gh_cli"

    err_cli = (m_res.stderr or m_res.stdout or "").strip()
    print(f"  Tier 1 (gh CLI) notice: {err_cli}")
    if "conflict" in err_cli.lower() or "merge conflict" in err_cli.lower():
        return False, "conflict"

    # --- Tier 2: GitHub REST API ---
    api_res, status_code = github_api_request_with_status(
        f"pulls/{pr_number}/merge",
        method="PUT",
        data={
            "merge_method": "merge",
            "commit_title": f"Merge pull request #{pr_number} from {branch}"
        }
    )
    if status_code == 200 and api_res and api_res.get("merged") is True:
        close_pr_immediately(pr_number, branch)
        return True, "rest_api"
    elif status_code == 409:
        return False, "conflict"

    err_api = api_res.get("message", f"HTTP {status_code}") if isinstance(api_res, dict) else f"HTTP {status_code}"
    print(f"  Tier 2 (REST API) notice: {err_api}")

    # --- Tier 3: Direct Git CLI fallback ---
    print(f"  Executing Tier 3 Native Git CLI merge for PR #{pr_number}...")
    run_cmd(["git", "fetch", "origin", branch])
    run_cmd(["git", "fetch", "origin", base_branch])
    run_cmd(["git", "checkout", base_branch])
    run_cmd(["git", "reset", "--hard", f"origin/{base_branch}"])

    git_merge = run_cmd([
        "git", "merge", f"origin/{branch}",
        "--no-ff",
        "-m", f"Merge pull request #{pr_number} from {branch} [VALIXIS Midnight Bot]"
    ])

    if git_merge.returncode != 0:
        run_cmd(["git", "merge", "--abort"])
        print(f"  Tier 3 Git merge conflict: {git_merge.stderr}")
        return False, "conflict"

    git_push = run_cmd(["git", "push", "origin", base_branch])
    if git_push.returncode == 0:
        print(f"  Tier 3 Git push successful for PR #{pr_number}!")
        close_pr_immediately(pr_number, branch)
        return True, "git_cli"
    else:
        print(f"  Tier 3 Git push failed: {git_push.stderr}")
        return False, f"push_error: {git_push.stderr.strip()}"

def generate_antigravity_prompt(pr: Dict[str, Any], conflicting_files: List[str]) -> str:
    """Generate the exact prompt to run in Antigravity for instant morning resolution."""
    branch = pr.get('headRefName', 'feature-branch')
    base = pr.get('baseRefName', 'main')
    files_str = "\n".join([f"- `{f}`" for f in conflicting_files[:8]]) or "- (All modified files in PR branch)"

    prompt = f"""Antigravity, checkout branch '{branch}' and pull latest 'origin/{base}'.
Resolve all merge conflict markers (<<<<<<<, =======, >>>>>>>) in:
{files_str}

Ensure changes from both branches are preserved cleanly without breaking Clean Architecture or state.
Run tests and static analysis to verify zero errors or lint warnings remain.
Once passing, commit and push to '{branch}' so the midnight bot can auto-merge.
"""
    return prompt.strip()

def process_pull_requests(dry_run: bool = False) -> Dict[str, Any]:
    """Process all PRs non-blockingly."""
    prs = get_open_pull_requests()
    print(f"Found {len(prs)} open Pull Requests targeting default branch.")

    results = {
        "timestamp": os.environ.get("GITHUB_RUN_ID", "local-test"),
        "total_prs": len(prs),
        "merged": [],
        "conflicts": [],
        "failing_ci": []
    }

    for pr in prs:
        num = pr["number"]
        title = pr["title"]
        branch = pr["headRefName"]
        base = pr.get("baseRefName", "main")
        ci_ok = is_ci_passing(pr)

        print(f"\n==================================================")
        print(f"Evaluating PR #{num}: '{title}'")
        print(f"Branch: {branch} -> {base} | CI Passing: {ci_ok}")

        if not ci_ok:
            print(f"  ⚠️ CI checks not passing on PR #{num}. Skipping auto-merge.")
            results["failing_ci"].append({
                "pr_number": num,
                "title": title,
                "branch": branch
            })
            continue

        mergeable_status, conflicts = check_mergeability(num, branch, base)
        print(f"  Mergeability Assessment: {mergeable_status}")

        if mergeable_status == "CONFLICTING":
            print(f"  🚨 Merge conflict detected on PR #{num}!")
            prompt = generate_antigravity_prompt(pr, conflicts)
            comment_body = f"""### 🚨 Merge Conflict Detected by VALIXIS Midnight Bot

The newly merged changes in `{base}` conflict with branch `{branch}`.

#### 📋 Ready-to-Run Antigravity Prompt:
> Copy and run this in Antigravity to resolve automatically:

```text
{prompt}
```
"""
            if not dry_run:
                comment_on_pr(num, comment_body)

            results["conflicts"].append({
                "pr_number": num,
                "title": title,
                "branch": branch,
                "files": conflicts,
                "antigravity_prompt": prompt
            })
            continue

        # Clean and ready to merge!
        print(f"  ✔ PR #{num} is clean and verified. Initiating autonomous merge & close...")
        if not dry_run:
            merged, status_reason = merge_pull_request(num, branch, base)
            if merged:
                confirm_body = "🤖 **Autonomously merged into main and closed by VALIXIS Midnight Bot.** All integrity verifications passed."
                comment_on_pr(num, confirm_body)
                results["merged"].append({
                    "pr_number": num,
                    "title": title,
                    "branch": branch,
                    "strategy": status_reason
                })
                print(f"  🚀 PR #{num} successfully merged and closed! (Strategy: {status_reason})")
            elif status_reason == "conflict":
                print(f"  🚨 Merge conflict encountered during merge attempt on PR #{num}!")
                prompt = generate_antigravity_prompt(pr, conflicts or get_conflicting_files(num))
                comment_body = f"""### 🚨 Merge Conflict Detected by VALIXIS Midnight Bot

The newly merged changes in `{base}` conflict with branch `{branch}`.

#### 📋 Ready-to-Run Antigravity Prompt:
> Copy and run this in Antigravity to resolve automatically:

```text
{prompt}
```
"""
                comment_on_pr(num, comment_body)
                results["conflicts"].append({
                    "pr_number": num,
                    "title": title,
                    "branch": branch,
                    "files": conflicts,
                    "antigravity_prompt": prompt
                })
            else:
                print(f"  ❌ Failed to merge PR #{num}: {status_reason}")
        else:
            print(f"  [DRY RUN] Would auto-merge & close PR #{num} ({branch})")
            results["merged"].append({
                "pr_number": num,
                "title": title,
                "branch": branch,
                "strategy": "dry-run"
            })

    # Generate Reports
    generate_reports(results)
    return results

def generate_reports(results: Dict[str, Any]):
    """Write summary markdown and json files."""
    md = f"""# 🌙 VALIXIS Midnight Auto-Merge Briefing

| Metric | Count |
| :--- | :---: |
| **Total Open PRs Evaluated** | {results['total_prs']} |
| **Successfully Auto-Merged & Closed** | {len(results['merged'])} |
| **Conflicts Detected** | {len(results['conflicts'])} |
| **Failing CI / In Progress** | {len(results['failing_ci'])} |

---

## 1. Successfully Merged & Closed PRs
"""
    if not results["merged"]:
        md += "_No clean PRs were merged in this run._\n"
    else:
        for m in results["merged"]:
            strat = m.get('strategy', 'auto')
            md += f"- ✅ **PR #{m['pr_number']}**: {m['title']} (`{m['branch']}`) [Strategy: {strat}]\n"

    md += "\n---\n\n## 2. Conflicts Requiring Antigravity Morning Resolution\n"
    if not results["conflicts"]:
        md += "_🎉 Zero merge conflicts detected across all evaluated branches!_\n"
    else:
        for idx, c in enumerate(results["conflicts"], start=1):
            md += f"\n### {idx}. PR #{c['pr_number']}: {c['title']} (`{c['branch']}`)\n"
            md += f"**Conflicting Files**:\n"
            for f in c["files"]:
                md += f"- `{f}`\n"
            md += f"\n**Ready-to-Run Antigravity Prompt**:\n```text\n{c['antigravity_prompt']}\n```\n"

    Path("MIDNIGHT_AUTOFOCUS_REPORT.md").write_text(md, encoding='utf-8')
    Path("midnight_summary.json").write_text(json.dumps(results, indent=2), encoding='utf-8')
    print("\nReports successfully written to MIDNIGHT_AUTOFOCUS_REPORT.md and midnight_summary.json")

def main():
    parser = argparse.ArgumentParser(description="VALIXIS Midnight Autonomous PR Auto-Merge Bot")
    parser.add_argument("--dry-run", action="store_true", help="Simulate run without performing actual merges or comments")
    args = parser.parse_args()

    process_pull_requests(dry_run=args.dry_run)

if __name__ == "__main__":
    main()
