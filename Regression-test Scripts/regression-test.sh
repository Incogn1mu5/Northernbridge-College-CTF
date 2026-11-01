#!/bin/bash
# regression-test.sh
# Usage: ./regression-test.sh <TARGET_IP>

TARGET_IP=$1

if [ -z "$TARGET_IP" ]; then
    echo "Usage: $0 <TARGET_IP>"
    exit 1
fi

BASE_URL="http://$TARGET_IP"
COOKIE_FILE="cookie.txt"

# Helper: Get HTTP Status Code
get_status_code() {
    local url="$1"
    curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 0 "$url" 2>/dev/null || echo "0"
}

# Helper: POST Request
post_request() {
    local url="$1"
    local data="$2"
    local cookie_jar="$3"
    if [ -n "$cookie_jar" ]; then
        curl -s -b "$cookie_jar" -c "$cookie_jar" -X POST -d "$data" "$url" 2>/dev/null
    else
        curl -s -X POST -d "$data" "$url" 2>/dev/null
    fi
}

# Helper: GET Response Body
get_response_body() {
    local url="$1"
    local cookie_jar="$2"
    if [ -n "$cookie_jar" ]; then
        curl -s -b "$cookie_jar" "$url" 2>/dev/null
    else
        curl -s "$url" 2>/dev/null
    fi
}

echo "========================================================="
echo " Starting Regression Test against $TARGET_IP"
echo "========================================================="

# ---------------------------------------------------------
# UNAUTHENTICATED TESTS
# ---------------------------------------------------------

echo -e "\n[NB-01] Testing Administrative Route Protection & Information Leakage..."
LOGIN_BODY=$(get_response_body "$BASE_URL/admin/index.php" "")
if echo "$LOGIN_BODY" | grep -q "backup: /\.env"; then
    echo -e "\033[31m[-] VULNERABLE: /admin/index.php leaks information (<!-- backup: /.env -->).\033[0m"
else
    echo -e "\033[32m[+] HARDENED: Unauthenticated login page leaks no internal paths.\033[0m"
fi

echo -e "\n[NB-02] Testing .env File Accessibility..."
STATUS_02=$(get_status_code "$BASE_URL/.env")
if [ "$STATUS_02" -eq 200 ]; then
    echo -e "\033[31m[-] VULNERABLE: .env file is accessible over HTTP (HTTP 200).\033[0m"
else
    echo -e "\033[32m[+] HARDENED: .env file is protected (HTTP $STATUS_02).\033[0m"
fi

echo -e "\n[NB-03] Testing Login Rate Limiting (Password Spraying)..."
RESP_03=""
for i in {1..6}; do
    RESP_03=$(post_request "$BASE_URL/admin/index.php" "username=emma.novak&password=WrongPassword123" "")
done
if echo "$RESP_03" | grep -q "Too many attempts"; then
    echo -e "\033[32m[+] HARDENED: Lockout mechanism engaged after 6 failed attempts.\033[0m"
else
    echo -e "\033[31m[-] VULNERABLE: No rate limit detected. Generic error returned on 6th attempt.\033[0m"
fi

# ---------------------------------------------------------
# AUTHENTICATED TESTS
# ---------------------------------------------------------

echo -e "\nLogging in to obtain session cookie..."
rm -f "$COOKIE_FILE"

# Try Vulnerable Credential First
LOGIN_RESP=$(curl -s -i -c "$COOKIE_FILE" -X POST -d "username=helen.carter&password=Winter2026!" "$BASE_URL/admin/index.php")

# If it fails, try Hardened Credential
if echo "$LOGIN_RESP" | grep -qE "Invalid administrator|Too many attempts"; then
    LOGIN_RESP=$(curl -s -i -c "$COOKIE_FILE" -X POST -d "username=helen.carter&password=Autumn2026!" "$BASE_URL/admin/index.php")
fi

# Verify we actually logged in (successful login returns 302 redirect to dashboard)
if ! echo "$LOGIN_RESP" | grep -q "Location: dashboard.php"; then
    echo -e "\033[33mERROR: Failed to obtain session cookie. Skipping authenticated tests.\033[0m"
    exit 1
fi

echo -e "\n[NB-04] Testing Cross-Department Authorization (Restricted View)..."
RESP_004=$(get_response_body "$BASE_URL/admin/edit-marks.php?id=NB-VS26-1003" "$COOKIE_FILE")
RESP_04=$(get_response_body "$BASE_URL/admin/edit-marks.php?id=NB-VS26-3001" "$COOKIE_FILE")

if echo "$RESP_004" | grep -q "Student not found" && echo "$RESP_04" | grep -q "Student not found"; then
    echo -e "\033[32m[+] HARDENED: Out-of-department student access rejected.\033[0m"
else
    echo -e "\033[31m[-] VULNERABLE: Successfully loaded out-of-department student form.\033[0m"
fi

echo -e "\n[NB-05] Testing SQL Injection in Search..."
SEARCH_PAYLOAD=$(python3 -c "import urllib.parse; print(urllib.parse.quote(\"' OR '1'='1\"))" 2>/dev/null || echo "%27%20OR%20%271%27=%271")
RESP_05=$(get_response_body "$BASE_URL/admin/edit-marks.php?search=$SEARCH_PAYLOAD" "$COOKIE_FILE")
if echo "$RESP_05" | grep -q "Kavya Singh"; then
    echo -e "\033[31m[-] VULNERABLE: SQL Injection successful. Unauthorized schema/rows dumped.\033[0m"
else
    echo -e "\033[32m[+] HARDENED: SQL Injection rejected. Payload treated as literal text.\033[0m"
fi

echo -e "\n[NB-06] Testing Local File Inclusion (LFI)..."
RESP_06=$(get_response_body "$BASE_URL/admin/edit-marks.php?id=/etc/passwd" "$COOKIE_FILE")
if echo "$RESP_06" | grep -q "root:x:0:0:"; then
    echo -e "\033[31m[-] VULNERABLE: LFI successful. Read /etc/passwd.\033[0m"
else
    echo -e "\033[32m[+] HARDENED: LFI rejected. Arbitrary file read prevented.\033[0m"
fi

# Cleanup
rm -f "$COOKIE_FILE"
echo -e "\n========================================================="
echo " Regression Test Complete"
echo "========================================================="
