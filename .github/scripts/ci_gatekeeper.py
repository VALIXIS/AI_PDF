"""
VALIXIS PR Gatekeeper — Self-Contained CI/CD Engine.
Runs directly in GitHub Actions runners.
"""

import sys
import os
import re
import subprocess
import json
from pathlib import Path

REPO_ROOT = Path(".").resolve()

def scan_security():
    issues = []
    conflict_patterns = [
        (r'^<{7}(?: .+)?$', "Unresolved merge conflict start (<<<<<<<)"),
        (r'^={7}$', "Unresolved merge conflict separator (=======)"),
        (r'^>{7}(?: .+)?$', "Unresolved merge conflict end (>>>>>>>)"),
    ]
    secret_patterns = [
        (r'(?i)(?:api_key|secret_key|auth_token)\s*[:=]\s*["\']([a-zA-Z0-9_\-\.]{20,})["\']', "Potential API key"),
        (r'AIza[0-9A-Za-z\-_]{35}', "Google API Key"),
        (r'-----BEGIN (?:RSA )?PRIVATE KEY-----', "Private Key block"),
    ]

    for root, dirs, files in os.walk(REPO_ROOT):
        dirs[:] = [d for d in dirs if d not in ('.git', '.dart_tool', 'build', 'node_modules', '__pycache__')]
        for f in files:
            p = Path(root) / f
            if p.name in ('gatekeeper.py', 'valixis_gatekeeper.yml', '.env.example'):
                continue
            try:
                if p.stat().st_size > 1_000_000:
                    continue
                content = p.read_text(encoding='utf-8', errors='ignore')
            except Exception:
                continue

            for idx, line in enumerate(content.splitlines(), start=1):
                clean = line.strip()
                for pat, msg in conflict_patterns:
                    if re.match(pat, clean):
                        issues.append({"type": "CONFLICT_MARKER", "severity": "CRITICAL", "file": str(p), "line": idx, "message": f"{msg} on line {idx}"})
                for pat, msg in secret_patterns:
                    if re.search(pat, line) and not any(k in clean.lower() for k in ('dummy', 'mock', 'fake', 'sample')):
                        issues.append({"type": "SECRET_LEAK", "severity": "CRITICAL", "file": str(p), "line": idx, "message": f"{msg} on line {idx}"})
    return issues

def scan_hive_type_ids():
    issues = []
    type_id_map = {}
    class_pat = re.compile(r'class\s+([A-Za-z0-9_]+)')

    for p in REPO_ROOT.glob('lib/**/*.dart'):
        if '.dart_tool' in p.parts or 'build' in p.parts:
            continue
        try:
            lines = p.read_text(encoding='utf-8', errors='ignore').splitlines()
        except Exception:
            continue

        for idx, line in enumerate(lines):
            match = re.search(r'@HiveType\s*\(\s*typeId:\s*(\d+)\s*\)', line)
            if match:
                tid = int(match.group(1))
                cname = "UnknownClass"
                for lookahead in lines[idx:idx + 6]:
                    cm = class_pat.search(lookahead)
                    if cm:
                        cname = cm.group(1)
                        break
                if tid not in type_id_map:
                    type_id_map[tid] = []
                type_id_map[tid].append((cname, p.name))

    for tid, entries in type_id_map.items():
        if len({c for c, _ in entries}) > 1 or len(entries) > 1:
            details = ", ".join([f"'{c}' in {f}" for c, f in entries])
            issues.append({
                "type": "HIVE_TYPE_ID_COLLISION",
                "severity": "CRITICAL",
                "file": "Hive Models",
                "line": 0,
                "message": f"Hive typeId {tid} is registered multiple times: {details}. Models must use strictly unique IDs!"
            })
    return issues

def run_flutter_checks():
    issues = []
    if not (REPO_ROOT / 'pubspec.yaml').exists():
        return issues

    # Flutter analyze
    res = subprocess.run(['flutter', 'analyze', '--no-fatal-infos'], capture_output=True, text=True, shell=True)
    if res.returncode != 0:
        raw = res.stdout or res.stderr
        diag_lines = [l.strip() for l in raw.splitlines() if re.search(r'\b(?:error|warning|info)\s+-\s+', l)]
        issues.append({
            "type": "LINTER_FAILURE",
            "severity": "CRITICAL",
            "file": "lib",
            "line": 0,
            "message": "Flutter static analysis reported issues:\n" + "\n".join(diag_lines)
        })

    # Flutter test
    if (REPO_ROOT / 'test').exists() and any((REPO_ROOT / 'test').glob('*_test.dart')):
        t_res = subprocess.run(['flutter', 'test'], capture_output=True, text=True, shell=True)
        if t_res.returncode != 0:
            issues.append({
                "type": "TEST_FAILURE",
                "severity": "CRITICAL",
                "file": "test",
                "line": 0,
                "message": "Flutter tests failed:\n" + (t_res.stdout or t_res.stderr)[:1000]
            })
    return issues

def main():
    issues = []
    issues.extend(scan_security())
    issues.extend(scan_hive_type_ids())
    issues.extend(run_flutter_checks())

    criticals = [i for i in issues if i["severity"] == "CRITICAL"]
    warnings = [i for i in issues if i["severity"] == "WARNING"]
    status_emoji = "❌ FAILED" if criticals else ("⚠️ PASSED WITH WARNINGS" if warnings else "✅ PASSED")

    report = f"""## 🤖 VALIXIS PR Gatekeeper Automated Audit

| Status | Critical Issues | Warnings |
| :---: | :---: | :---: |
| **{status_emoji}** | **{len(criticals)}** | **{len(warnings)}** |

"""
    if not issues:
        report += "\n> 🎉 **All verifications passed!** Clean architecture, Hive schemas, and static analysis verified.\n"
    else:
        report += "### Findings Requiring Attention\n\n"
        for idx, issue in enumerate(issues, start=1):
            badge = "🚨 CRITICAL" if issue["severity"] == "CRITICAL" else "⚠️ WARNING"
            report += f"**{idx}. [{badge}] `{issue['type']}`**\n"
            report += f"- Target: `{issue.get('file', 'repo')}`\n"
            report += f"- Details: {issue['message']}\n\n"

    Path("GATEKEEPER_REPORT.md").write_text(report, encoding='utf-8')
    print(report)

    if criticals:
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
