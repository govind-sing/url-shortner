#!/bin/bash

BASE_URL="http://localhost:8000"
PASS=0
FAIL=0
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check() {
  local label=$1
  local response=$2
  local expected=$3

  if echo "$response" | grep -q "$expected"; then
    echo -e "${GREEN}✓ $label${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ $label${NC}"
    echo -e "  Expected to find: $expected"
    echo -e "  Got: $response"
    FAIL=$((FAIL + 1))
  fi
}

print_response() {
  local label=$1
  local response=$2
  echo -e "  ${YELLOW}↳ $label:${NC} $response" | python3 -c "
import sys, json
line = sys.stdin.read()
prefix = line.split('{')[0] if '{' in line else ''
json_str = line[len(prefix):]
try:
    data = json.loads(json_str.strip())
    print(prefix + json.dumps(data, indent=4))
except:
    print(line, end='')
" 2>/dev/null || echo -e "  ${YELLOW}↳ $label:${NC} $response"
  echo ""
}

echo -e "\n${YELLOW}=== URL Shortener API Test Suite ===${NC}\n"

# ─────────────────────────────────────────
echo -e "${YELLOW}── Auth ──${NC}"
# ─────────────────────────────────────────
# unique run ID so tests are always fresh
RUN_ID=$(date +%s)
TEST_EMAIL="testuser_${RUN_ID}@example.com"
TEST_USERNAME="testuser_${RUN_ID}"

# Register
REGISTER=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"username\":\"$TEST_USERNAME\",\"password\":\"secret123\"}")
check "Register new user" "$REGISTER" "$TEST_EMAIL"
print_response "Created user" "$REGISTER"

# Duplicate email
DUP_EMAIL=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"username\":\"${TEST_USERNAME}_2\",\"password\":\"secret123\"}")
check "Reject duplicate email" "$DUP_EMAIL" "Email already registered"
print_response "Server response" "$DUP_EMAIL"

# Duplicate username
DUP_USER=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"other_${RUN_ID}@example.com\",\"username\":\"$TEST_USERNAME\",\"password\":\"secret123\"}")
check "Reject duplicate username" "$DUP_USER" "Username already taken"
print_response "Server response" "$DUP_USER"

# Login
LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$TEST_EMAIL&password=secret123")
check "Login with valid credentials" "$LOGIN" "access_token"
print_response "Token issued" "$LOGIN"
TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Wrong password
WRONG_PASS=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser@example.com&password=wrongpass")
check "Reject wrong password" "$WRONG_PASS" "Incorrect email or password"
print_response "Server response" "$WRONG_PASS"

# ─────────────────────────────────────────
echo -e "\n${YELLOW}── URL Shortening ──${NC}"
# ─────────────────────────────────────────

# Create URL
CREATE=$(curl -s -X POST "$BASE_URL/urls" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"original_url":"https://github.com/govind-sing"}')
check "Create short URL" "$CREATE" "short_code"
print_response "Short URL created" "$CREATE"
SHORT_CODE=$(echo "$CREATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['short_code'])")
URL_ID=$(echo "$CREATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# Custom alias
ALIAS="goog${RUN_ID}"
CUSTOM=$(curl -s -X POST "$BASE_URL/urls" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"original_url\":\"https://google.com\",\"custom_alias\":\"$ALIAS\"}")
check "Create URL with custom alias" "$CUSTOM" "$ALIAS"
print_response "Custom alias created" "$CUSTOM"
CUSTOM_ID=$(echo "$CUSTOM" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# Duplicate alias
DUP_ALIAS=$(curl -s -X POST "$BASE_URL/urls" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"original_url\":\"https://bing.com\",\"custom_alias\":\"$ALIAS\"}")
check "Reject duplicate custom alias" "$DUP_ALIAS" "already taken"
print_response "Server response" "$DUP_ALIAS"

# Unauthenticated create
UNAUTH=$(curl -s -X POST "$BASE_URL/urls" \
  -H "Content-Type: application/json" \
  -d "{\"original_url\":\"https://github.com\"}")
check "Reject unauthenticated create" "$UNAUTH" "Not authenticated"
print_response "Server response" "$UNAUTH"

# ─────────────────────────────────────────
echo -e "\n${YELLOW}── Redirect ──${NC}"
# ─────────────────────────────────────────

REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" -L "http://localhost:8000/$SHORT_CODE")
check "Redirect returns 200 after following" "$REDIRECT" "200"
print_response "HTTP status" "$REDIRECT"

REDIRECT_CUSTOM=$(curl -s -o /dev/null -w "%{http_code}" -L "http://localhost:8000/$ALIAS")
check "Custom alias redirects correctly" "$REDIRECT_CUSTOM" "200"
print_response "HTTP status" "$REDIRECT_CUSTOM"

REDIRECT_404=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8000/doesnotexist")
check "Unknown short code returns 404" "$REDIRECT_404" "404"
print_response "HTTP status" "$REDIRECT_404"

# ─────────────────────────────────────────
echo -e "\n${YELLOW}── URL Management ──${NC}"
# ─────────────────────────────────────────

LIST=$(curl -s "$BASE_URL/urls" -H "Authorization: Bearer $TOKEN")
check "List URLs returns array" "$LIST" "short_code"
print_response "User URLs" "$LIST"


UPDATE=$(curl -s -X PATCH "$BASE_URL/urls/$URL_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"custom_alias\":\"myrepo_${RUN_ID}\"}")
check "Update URL alias" "$UPDATE" "myrepo_${RUN_ID}"
print_response "Updated URL" "$UPDATE"

# verify old code is gone from Redis
OLD_CACHE=$(docker-compose exec -T redis redis-cli GET "url:$SHORT_CODE")
check "Old alias evicted from Redis cache" "$OLD_CACHE" ""
print_response "Redis GET old key" "${OLD_CACHE:-"(nil) — cache cleared correctly"}"


# verify new alias redirects
NEW_REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" -L "http://localhost:8000/myrepo_${RUN_ID}")
check "New alias redirects correctly" "$NEW_REDIRECT" "200"
print_response "HTTP status" "$NEW_REDIRECT"

DELETE=$(curl -s -X DELETE "$BASE_URL/urls/$CUSTOM_ID" -H "Authorization: Bearer $TOKEN")
check "Delete URL returns success" "$DELETE" "deleted successfully"
print_response "Server response" "$DELETE"

DELETED_REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8000/$ALIAS")
check "Deleted URL returns 404" "$DELETED_REDIRECT" "404"
print_response "HTTP status" "$DELETED_REDIRECT"


# ─────────────────────────────────────────
echo -e "\n${YELLOW}── Analytics ──${NC}"
# ─────────────────────────────────────────


ANALYTICS=$(curl -s "$BASE_URL/urls/$URL_ID/analytics" -H "Authorization: Bearer $TOKEN")
check "Analytics returns click count" "$ANALYTICS" "total_clicks"
CLICK_COUNT=$(echo "$ANALYTICS" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d['total_clicks'] > 0 else 'zero')")
check "Analytics total_clicks > 0" "$CLICK_COUNT" "ok"
check "Analytics returns last_accessed" "$ANALYTICS" "last_accessed"
print_response "Analytics data" "$ANALYTICS"

# ─────────────────────────────────────────
echo -e "\n${YELLOW}── Logout + Token Revocation ──${NC}"
# ─────────────────────────────────────────

LOGOUT=$(curl -s -X POST "$BASE_URL/auth/logout" -H "Authorization: Bearer $TOKEN")
check "Logout succeeds" "$LOGOUT" "Successfully logged out"
print_response "Server response" "$LOGOUT"


REVOKED=$(curl -s -X POST "$BASE_URL/auth/logout" -H "Authorization: Bearer $TOKEN")
check "Revoked token rejected" "$REVOKED" "Token has been revoked"
print_response "Server response" "$REVOKED"


REVOKED_URL=$(curl -s "$BASE_URL/urls" -H "Authorization: Bearer $TOKEN")
check "Revoked token rejected on protected route" "$REVOKED_URL" "Token has been revoked"
print_response "Server response" "$REVOKED_URL"

# ─────────────────────────────────────────
echo -e "\n${YELLOW}── Results ──${NC}"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo ""