#!/usr/bin/env bash
# WMS App User Role ataması yapan helper.
# Çalıştırma:
#   BC_TOKEN=<bearer-token> ./tools/wms-add-user.sh <email> <role> [tenant] [env] [companyId]
# Default'lar (BCWMS sandbox):
#   tenant = 7fa2357e-26f2-4174-8e16-a713981356b8
#   env    = CustomerSandbox
#   role   = INV_ADMIN
# Role kodları (al/src/Role/AppRoleSeed.Codeunit.al):
#   OPERATOR | PICKER | RECEIVER | SHIPPER | COUNTER | QUALITY | INV_ADMIN

set -eu

EMAIL="${1:-}"
ROLE="${2:-INV_ADMIN}"
TENANT="${3:-7fa2357e-26f2-4174-8e16-a713981356b8}"
ENV="${4:-CustomerSandbox}"
COMPANY_ID="${5:-}"

if [[ -z "${EMAIL}" ]]; then
  echo "usage: BC_TOKEN=<token> $0 <email> [role] [tenant] [env] [companyId]" >&2
  exit 2
fi
if [[ -z "${BC_TOKEN:-}" ]]; then
  echo "error: BC_TOKEN env var gerekli (bearer access_token)" >&2
  exit 2
fi

BASE="https://api.businesscentral.dynamics.com/v2.0/${TENANT}/${ENV}/api"

resolve_company_id() {
  if [[ -n "${COMPANY_ID}" ]]; then echo "${COMPANY_ID}"; return; fi
  # Default: first company in the env
  curl -fsS -H "Authorization: Bearer ${BC_TOKEN}" \
    "${BASE}/v2.0/companies?\$top=1&\$select=id,name" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["value"][0]["id"])'
}

CID="$(resolve_company_id)"
URL="${BASE}/dynops/warehouse/v2.0/companies(${CID})/appUserRoles"

echo "→ Posting role assignment"
echo "  user: ${EMAIL}"
echo "  role: ${ROLE}"
echo "  env : ${TENANT}/${ENV}/${CID}"
echo "  url : ${URL}"

# OData header: prefer return=representation for visibility into the row that was created.
RESPONSE=$(curl -sS -w "\nHTTP=%{http_code}\n" \
  -H "Authorization: Bearer ${BC_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{\"userId\":\"${EMAIL}\",\"roleCode\":\"${ROLE}\",\"priority\":100}" \
  -X POST "${URL}")

echo "${RESPONSE}"
HTTP=$(echo "${RESPONSE}" | grep -E '^HTTP=' | tail -1 | sed 's/HTTP=//')

if [[ "${HTTP}" == "201" || "${HTTP}" == "200" ]]; then
  echo "✅ assigned"
  exit 0
fi
echo "❌ failed (HTTP ${HTTP})" >&2
exit 1
