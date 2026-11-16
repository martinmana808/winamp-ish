#!/bin/bash
# Prints every email collected by the landing page, with the date it signed up.
set -euo pipefail
cd "$(dirname "$0")"

vercel env pull .env.local --yes >/dev/null 2>&1
set -a; source .env.local; set +a

curl -s "$KV_REST_API_URL/hgetall/downloads" -H "Authorization: Bearer $KV_REST_API_TOKEN" |
  python3 -c '
import json, sys
items = json.load(sys.stdin).get("result") or []
pairs = sorted(zip(items[1::2], items[::2]))
for date, email in pairs:
    print(date[:10], email)
print(f"\n{len(pairs)} emails")
'
