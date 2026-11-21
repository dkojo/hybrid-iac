"""Compare the settings Ansible read from the on-prem and AWS servers, and fail on any difference.

  python scripts/parity.py parity/onprem-rocky.txt parity/aws-ec2.txt
"""
import os
import sys


def read(path):
    """Each line is "setting=value"; the value may itself contain "=" (like a sudo rule)."""
    with open(path, encoding="utf-8") as f:
        return dict(line.split("=", 1) for line in f.read().splitlines() if "=" in line)


left, right = read(sys.argv[1]), read(sys.argv[2])

keys = sorted(set(left) | set(right))
width = max(len(k) for k in keys)
rows = []
for k in keys:
    a, b = left.get(k, "missing"), right.get(k, "missing")
    rows.append((a == b, f"{'MATCH' if a == b else 'DIFF '}  {k.ljust(width)}  on-prem: {a}   aws: {b}"))

print("\n".join(line for _, line in rows))
matched = sum(1 for ok, _ in rows if ok)
print(f"\n{matched}/{len(rows)} settings match across on-prem and AWS")

summary = os.environ.get("GITHUB_STEP_SUMMARY")
if summary:
    with open(summary, "a", encoding="utf-8") as f:
        f.write(f"### Parity: {matched}/{len(rows)} settings match\n\n```\n" + "\n".join(l for _, l in rows) + "\n```\n")
sys.exit(0 if matched == len(rows) else 1)
