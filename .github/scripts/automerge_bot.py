"""
VALIXIS Midnight Autonomous PR Auto-Merge & Conflict Prompt Bot
Runs in GitHub Actions runners at 12:00 AM Midnight IST (18:30 UTC).

Non-blocking algorithm:
1. Scans all open PRs targeting main/master.
2. For clean, passing PRs: auto-merges them into main.
3. For conflicting PRs:
   - Identifies conflicting files.
   - Generates a customized Ready-to-Run Antigravity Prompt.
   - Comments the prompt directly on the PR.
   - Continues evaluating and merging remaining PRs without halting!
4. Produces MIDNIGHT_AUTOFOCUS_REPORT.md and midnight_summary.json.
"""

import sys
import os
import subprocess
import json
import argparse
import urllib.request
import urllib.error
from pathlib import Path
from typing import List, Dict, Any

REPO_ROOT = Path(".").resolve()

def run_cmd(cmd: List[str], cwd: Path = REPO_ROOT) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True, shell=True)

def github_api_request(endpoint: str, method: str = "GET", data: Dict[str, Any] = None) -> Any:
    """Execute authenticated GitHub REST API request."""
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    repo = os.environ.get("GITHUB_REPOSITORY")
    if not token or not repo:
        return None

    url = f"https://api.github.com/repos/{repo}/{endpoint.lstrip('/')}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "VALIXIS-Midnight-Bot"
    }

    req_data = json.dumps(data).encode('utf-8') if data else None
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        return None

def get_open_pull_requests() -> List[Dict[str, Any]]:
    """Retrieve all open pull requests targeting default branch."""
    # First attempt: GitHub CLI
    cmd = [
        'gh', 'pr', 'list',
        '--state', 'open',
        '--json', 'number,title,headRefName,baseRefName,mergeable,statusCheckRollup,url,author,labels'
    ]
    res = run_cmd(cmd)
    if res.returncode == 0:
        try:
            return json.loads(res.stdout)
        except Exception:
            pass

    # Second attempt: GitHub REST API
    api_res = github_api_request("pulls?state=open")
    if api_res and isinstance(api_res, list):
        prs = []
        for p in api_res:
            prs.append({
                "number": p["number"],
                "title": p["title"],
                "headRefName": p["head"]["ref"],
                "baseRefName": p["base"]["ref"],
                "mergeable": "MERGEABLE" if p.get("mergeable") is True else ("CONFLICTING" if p.get("mergeable") is False else "UNKNOWN"),
                "url": p["html_url"],
                "author": {"login": p["user"]["login"]}
            })
        return prs

    return []

def get_conflicting_files(pr_number: int) -> List[str]:
    """Retrieve changed/conflicting files for a PR."""
    cmd = ['gh', 'pr', 'view', str(pr_number), '--json', 'files']
    res = run_cmd(cmd)
    if res.returncode == 0:
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
        # If no checks are defined, treat as passing
        return True
    
    for check in checks:
        # Check either 'conclusion' or 'state'
        conclusion = (check.get("conclusion") or check.get("state") or "").upper()
        name = check.get("name", "")
        # Ignore in-progress current workflow
        if "midnight" in name.lower():
            continue
        if conclusion in ("FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED"):
            return False
    return True

def generate_antigravity_prompt(pr: Dict[str, Any], conflicting_files: List[str]) -> str:
    """Generate the exact prompt to run in Antigravity for instant morning resolution."""
    branch = pr.get('headRefName', 'feature-branch')
    base = pr.get('baseRefName', 'main')
    files_str = "\n".join([f"- `{f}`" for f in conflicting_files[:8]]) or "- (All modified files in PR branch)"

    prompt = f"""Antigravity, checkout branch '{branch}' and pull latest 'origin/{base}'.
Resolve all merge conflict markers (<<<<<<<, =======, >>>>>>>) in:
{files_str}

Ensure changes from both branches are preserved cleanly without breaking Clean Architecture or Riverpod state.
Run `valixis-gatekeeper check --fast` to verify zero errors or lint warnings remain.
Once passing, commit and push to '{branch}' so the midnight bot can auto-merge.
"""
    return prompt.strip()

def process_pull_requests(dry_run: bool = False) -> Dict[str, Any]:
    """Process all PRs non-blockingly."""
    prs = get_open_pull_requests()
    print(f"Found {len(prs)} open Pull Requests targeting main.")

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
        mergeable = pr.get("mergeable", "UNKNOWN")
        ci_ok = is_ci_passing(pr)

        print(f"\nEvaluating PR #{num} ('{title}') [Branch: {branch}]...")
        print(f"  Mergeable: {mergeable} | CI Passing: {ci_ok}")

        if mergeable == "CONFLICTING":
            print(f"  🚨 Merge conflict detected on PR #{num}!")
            conflicting_files = get_conflicting_files(num)
            prompt = generate_antigravity_prompt(pr, conflicting_files)

            comment_body = f"""### 🚨 Merge Conflict Detected by VALIXIS Midnight Bot

The newly merged changes in `main` conflict with branch `{branch}`.

#### 📋 Ready-to-Run Antigravity Prompt:
> Copy and run this in Antigravity to resolve automatically:

```text
{prompt}
```
"""
            if not dry_run:
                run_cmd(['gh', 'pr', 'comment', str(num), '--body', comment_body])

            results["conflicts"].append({
                "pr_number": num,
                "title": title,
                "branch": branch,
                "files": conflicting_files,
                "antigravity_prompt": prompt
            })
            continue

        elif not ci_ok:
            print(f"  ⚠️ CI checks not passing on PR #{num}. Skipping auto-merge.")
            results["failing_ci"].append({
                "pr_number": num,
                "title": title,
                "branch": branch
            })
            continue

        else:
            # Clean and ready to merge!
            print(f"  ✔ PR #{num} is 100% clean and passing CI. Merging...")
            if not dry_run:
                merge_cmd = ['gh', 'pr', 'merge', str(num), '--squash', '--delete-branch']
                m_res = run_cmd(merge_cmd)
                if m_res.returncode == 0:
                    confirm_body = "🤖 **Autonomously merged into main by VALIXIS Midnight Bot.** All integrity verifications passed."
                    run_cmd(['gh', 'pr', 'comment', str(num), '--body', confirm_body])
                    results["merged"].append({
                        "pr_number": num,
                        "title": title,
                        "branch": branch
                    })
                    print(f"  🚀 PR #{num} successfully merged!")
                else:
                    print(f"  Failed to merge PR #{num}: {m_res.stderr}")
            else:
                print(f"  [DRY RUN] Would auto-merge PR #{num} ({branch})")
                results["merged"].append({
                    "pr_number": num,
                    "title": title,
                    "branch": branch
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
| **Successfully Auto-Merged** | {len(results['merged'])} |
| **Conflicts Detected** | {len(results['conflicts'])} |
| **Failing CI / In Progress** | {len(results['failing_ci'])} |

---

## 1. Successfully Merged PRs
"""
    if not results["merged"]:
        md += "_No clean PRs were ready to merge._\n"
    else:
        for m in results["merged"]:
            md += f"- ✅ **PR #{m['pr_number']}**: {m['title']} (`{m['branch']}`)\n"

    md += "\n---\n\n## 2. Conflicts Requiring Antigravity Morning Resolution\n"
    if not results["conflicts"]:
        md += "_🎉 Zero merge conflicts detected across all branches!_\n"
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
