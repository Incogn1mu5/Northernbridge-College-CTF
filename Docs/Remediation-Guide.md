# Remediation Guide

Target: Northernbridge College Portal (Hardened Build)

## 1. How to Use This Guide

This guide documents the technical fixes for all six findings identified in the Northernbridge College Portal.

The repository now contains two distinct builds:
- Vulnerable Build: The default CTF target (`vagrant up`). Used by students.
- Hardened Build: The verification artifact (`vagrant up hardened`). Never deployed to students. It lives in the `hardened/` directory.

To verify a fix, run the verification commands against the default vulnerable VM first (to prove the test accurately detects the flaw), and then against the hardened VM (to prove the flaw is closed).  
</br>  

## 2. Ground Rules for Every Fix

When writing or reviewing code for this application, the following non-negotiables apply:
1. **Authorize on the server:** Never rely on the UI to hide a control. Every request must be authorized on the server side.
2. **Parameterize all queries:** Never build a database query by concatenating user input into a string.
3. **Protect configuration files:** Never serve configuration, credential, or environment dotfiles from the web root. Store secrets outside the document root.
4. **No security by obscurity:** An unlinked route is not a hidden route. Protect routes with real access controls.
5. **Assume public exposure means compromised:** Any secret served publicly must be rotated immediately.  
</br>  

## 3. Finding Remediations

### NB-05: SQL Injection in Administrative Search Functionality

- **The problem:** The student search parameter `?search=` was concatenated directly into the SQL query, allowing an attacker to alter the query logic and bypass intended restrictions.  
- **Why the obvious fix is not enough:** Attempting to sanitize the input using string escaping (e.g., addslashes or regex blocklists) is fragile and frequently bypassed. The only complete fix is separating the SQL structure from the data.  
- **The fix:** Replace the concatenated query with a parameterized prepared statement, binding the search input as a value.  

*Before (Vulnerable www/admin/edit-marks.php):*

``` php
 
$query = "
    SELECT s.student_id, s.first_name, s.last_name, s.department,
           m.math, m.cpp, m.python, m.graphics
    FROM students s
    LEFT JOIN marks m ON s.student_id = m.student_id
    WHERE (
        s.first_name LIKE '%$search%'
        OR s.last_name LIKE '%$search%'
        OR s.student_id LIKE '%$search%'
        OR s.department LIKE '%$search%'
    ) AND s.student_id LIKE 'NB-%' ORDER BY s.student_id
";
$result = $db->query($query);
```

*After (Hardened hardened/www/admin/edit-marks.php):*
``` PHP
 $likePattern = '%' . $search . '%';

    $stmt = $db->prepare('
        SELECT s.student_id, s.first_name, s.last_name, s.department, m.math, m.cpp, m.python, m.graphics
        FROM students s
        LEFT JOIN marks m ON s.student_id = m.student_id
        WHERE ( s.first_name LIKE :pattern
            OR s.last_name LIKE :pattern
            OR s.student_id LIKE :pattern
            OR s.department LIKE :pattern
        ) AND s.department = :department
        ORDER BY s.student_id
    ');

    $stmt->bindValue(':pattern', $likePattern, SQLITE3_TEXT);
    // Bind the department variable to enforce the boundary
    $stmt->bindValue(':department', $adminDepartment, SQLITE3_TEXT);
$result = $stmt->execute();
```

**Configuration or infrastructure changes:** None.  
**Migration / rollout notes:** None.  
**Verification:** Submit a structural test pattern (e.g., ' OR '1'='1) to the search field. The hardened build treats it as literal text and returns no results.  
**Regression test:** test_admin_search_sqli_rejection  
**Residual risk:** None.  
</br>  

### NB-06: Local File Inclusion Through Unvalidated File Path Parameter

- **The problem:** The `id=` parameter evaluated input starting with `/` as an absolute file path and passed it to `file_get_contents()`, allowing the reading of arbitrary server files.  
- **Why the obvious fix is not enough:** Using a blocklist (e.g., stripping `../` or `/etc/passwd`) fails because attackers can use encoding or alternative paths.
- **The fix:** Remove the file-reading logic entirely. Replace it with a strict database query lookup that only fetches known student IDs via a helper function.

*Before (Vulnerable www/admin/edit-marks.php):* 
``` PHP
if ($edit_id !== '' && str_starts_with($edit_id, '/')) {
    if (is_file($edit_id) && is_readable($edit_id)) {
        $file_contents = file_get_contents($edit_id);
    }
}
```

*After (Hardened hardened/www/admin/edit-marks.php):*
``` PHP
$selected_student = $edit_id !== ''
    ? fetch_authorized_student($db, $edit_id, $adminDepartment)
    : null;

if ($edit_id !== '' && $selected_student === null) {
    $message = 'Student not found.';
    $message_type = 'error';
}
```

**Configuration or infrastructure changes:** None.  
**Migration / rollout notes:** None.  
**Verification:** Request `/admin/edit-marks.php?id=/etc/passwd`. The hardened build returns "Student not found" with no file output.  
**Regression test:** test_admin_lfi_rejection  
**Residual risk:** The web user (`www-data`) still requires read access to application files; least privilege must be maintained at the OS level.  
</br>  

### NB-04: Inadequate Authorization Controls in Restricted Clerk View

- **The problem:** Departmental scoping was only enforced on the default (empty search) query branch. Searching for an out-of-scope student ID returned their record, and updating out-of-scope marks was permitted.
- **Why the obvious fix is not enough:** Hiding out-of-scope students from the UI table does not prevent an attacker from passing their ID directly into the update POST request.
- **The fix:** Enforce authorization at the data-access layer by validating the authenticated admin's department against the requested student's department during both the SELECT and UPDATE operations.

*Before (Vulnerable www/admin/edit-marks.php update logic):*
``` PHP
$stmt = $db->prepare('
    UPDATE marks
    SET math = :math, cpp = :cpp, python = :python, graphics = :graphics
    WHERE student_id = :student_id
');
```

*After (Hardened hardened/www/includes/student-access.php):*
``` PHP
function fetch_authorized_student(SQLite3 $db, string $studentId, string $adminDepartment): ?array {
    $stmt = $db->prepare('
        SELECT s.student_id, s.first_name, s.last_name, s.department,
               m.math, m.cpp, m.python, m.graphics
        FROM students s
        LEFT JOIN marks m ON s.student_id = m.student_id
        WHERE s.student_id = :student_id AND s.department = :department
        LIMIT 1
    ');
    $stmt->bindValue(':student_id', $studentId, SQLITE3_TEXT);
    $stmt->bindValue(':department', $adminDepartment, SQLITE3_TEXT);
    $result = $stmt->execute();
    $row = $result ? $result->fetchArray(SQLITE3_ASSOC) : false;
    return $row ?: null;
}
```
`hardened/www/admin/edit-marks.php` calls it directly for the `id=`
lookup:
```php
$selected_student = $edit_id !== ''
    ? fetch_authorized_student($db, $edit_id, $adminDepartment)
    : null;
```
Deliberately, this means **search can surface a record an admin is not permitted to open** — e.g. another department's `NB-*` & `NC-*` student shows up in a search result, but clicking "Edit Marks" on it is denied by this helper. That split is intentional, not a gap: "finding" and "editing" are different operations with different legitimate scopes.  

**Configuration or infrastructure changes:** Multi-department admin users created in `hardened_seed.sql`.  
**Migration / rollout notes:** Administrators will lose the ability to `edit` students outside their explicitly assigned department.  
**Verification:** Log in as an `IT admin` and attempt to edit a Civil Engineering student via direct ID manipulation. The hardened build drops the update.  
**Regression test:** test_admin_cross_department_authorization  
**Residual risk:** None.  
</br>  

### NB-03: Weak Authentication Controls Enable Password Spraying

- **The problem:** The admin login lacked rate limiting, allowing infinite password attempts against known usernames.
- **Why the obvious fix is not enough:** Implementing a CAPTCHA alone is frequently bypassed by automated solvers. Blocking by IP alone can cause collateral denial of service for shared networks.
- **The fix:** Implement a lockout mechanism tied to a combined `Client IP` and `Username key`, enforce secure password hashing (password_hash), and record failures to a dedicated SQLite table.  

**(a) Passwords are hashed, not compared in plaintext.** The `admins`
table column is renamed to `password_hash` and `index.php` verifies
with `password_verify()`:

*Before (Vulnerable www/admin/index.php):*
``` PHP
if ($admin && hash_equals($admin['password'], $password)) {
    // login success
}
```

*After (Hardened hardened/www/admin/index.php):*
```php
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    $clientKey = $_SERVER['REMOTE_ADDR'] . '|' . strtolower($username);

    if (login_is_locked_out($db, $clientKey)) {
        $error = 'Too many attempts. Please try again later.';
    } else {
        $stmt = $db->prepare("
            SELECT id, username, name, password_hash
            FROM admins WHERE username = :username LIMIT 1
        ");
        $stmt->bindValue(':username', $username, SQLITE3_TEXT);
        $admin = $stmt->execute()->fetchArray(SQLITE3_ASSOC);

        if ($admin && password_verify($password, $admin['password_hash'])) {
            login_clear_attempts($db, $clientKey);
            session_regenerate_id(true);
            $_SESSION['admin_logged_in'] = true;
            $_SESSION['admin_id'] = $admin['id'];
            header('Location: dashboard.php');
            exit;
        } else {
            login_record_failure($db, $clientKey);
            error_log('[Northernbridge-hardened] failed admin login for '
                . $username . ' from ' . $_SERVER['REMOTE_ADDR']);
            $error = 'Invalid administrator username or password.';
        }
    }
}
```

**(b) Throttling and lockout:** 

*Added (hardened/www/includes/login-throttle.php)*
``` PHP
<?php
const LOGIN_MAX_ATTEMPTS     = 5;
const LOGIN_LOCKOUT_SECONDS  = 300;

function login_is_locked_out(SQLite3 $db, string $key): bool
{
    $stmt = $db->prepare('SELECT attempts, last_attempt FROM login_attempts WHERE attempt_key = :key');
    $stmt->bindValue(':key', $key, SQLITE3_TEXT);
    $row = $stmt->execute()->fetchArray(SQLITE3_ASSOC);

    if (!$row) {
        return false;
    }

    $withinWindow = (time() - (int)$row['last_attempt']) < LOGIN_LOCKOUT_SECONDS;
    return $withinWindow && (int)$row['attempts'] >= LOGIN_MAX_ATTEMPTS;
}

function login_record_failure(SQLite3 $db, string $key): void
{
    $stmt = $db->prepare('
        INSERT INTO login_attempts (attempt_key, attempts, last_attempt)
        VALUES (:key, 1, :now)
        ON CONFLICT(attempt_key) DO UPDATE SET
            attempts = attempts + 1,
            last_attempt = :now
    ');
    $stmt->bindValue(':key', $key, SQLITE3_TEXT);
    $stmt->bindValue(':now', time(), SQLITE3_INTEGER);
    $stmt->execute();
}

function login_clear_attempts(SQLite3 $db, string $key): void
{
    $stmt = $db->prepare('DELETE FROM login_attempts WHERE attempt_key = :key');
    $stmt->bindValue(':key', $key, SQLITE3_TEXT);
    $stmt->execute();
}
```


**(c) Admin credential hashed automatically at provisioning time**
No value copied from the vulnerable build's exposed `.env`/seed data — All admin creds are hashed and stored in to the database:

*Before (Vulnerable infra/provision.sh):*
``` bash
cat > "$DECOY_ENV" <<'ENV'
APP_ENV=production
APP_URL=http://northernbridge.local
APP_DEBUG=false

DB_CONNECTION=sqlite
DB_DATABASE=/var/www/html/database/college.db

helen.carter:Winter2026!
anil.mehta:Northbridge@2026
priya.kannan:CollegeAdmin!99
david.okafor:Admin#2024
sara.ahmed:PortalPass!7
mohammed.khan:SecureIT@21
lina.farouk:NBCadmin2023
rohan.singh:FallBack!88
emily.wong:Winter2025!
gregory.adams:Admin1@one
fatima.hassan:Autumn#2022
peter.novak:March2026!
ENV
echo "  decoy .env written."
```

*After (Hardened hardened/infra/hardened_provision.sh):*
```bash
# hardened/infra/hardened_provision.sh — step [6/7], runs AFTER schema
# creation (step [5/7]), not before — an earlier draft had this backwards,
# which failed on a fresh VM because the admins table didn't exist yet.
ADMIN_USERNAME="helen.carter"
ADMIN_DEPARTMENT="Information Technology"
ADMIN_PASSWORD="Autumn2026!"

php -r '
$db = new SQLite3($argv[1]);
$hash = password_hash($argv[4], PASSWORD_DEFAULT);
$stmt = $db->prepare(
    "INSERT OR IGNORE INTO admins (username, password_hash, name, number, salary, department)
     VALUES (:username, :hash, :name, :number, :salary, :department)"
);
$stmt->bindValue(":username", $argv[2], SQLITE3_TEXT);
$stmt->bindValue(":hash", $hash, SQLITE3_TEXT);
$stmt->bindValue(":name", "Helen Carter", SQLITE3_TEXT);
$stmt->bindValue(":number", "9457623547", SQLITE3_TEXT);
$stmt->bindValue(":salary", 75000, SQLITE3_FLOAT);
$stmt->bindValue(":department", $argv[3], SQLITE3_TEXT);
$stmt->execute();
' "$DB_PATH" "$ADMIN_USERNAME" "$ADMIN_DEPARTMENT" "$ADMIN_PASSWORD"
```

**Configuration or infrastructure changes:** Added login_attempts table to hardened_seed.sql. Migrated plaintext password column to password_hash.  
**Migration / rollout notes:** Existing plaintext passwords in the database must be re-hashed using password_hash() prior to deployment.  
**Verification:** Issue 6 incorrect login requests for the same user. The 6th request will return "Too many attempts" regardless of password correctness.  
**Regression test:** test_admin_login_rate_limiting  
**Residual risk:** Distributed attacks using rotating IP addresses can still attempt slow sprays.  
</br>  

### NB-02: Sensitive Credentials Exposed in Public Configuration File

- **The problem:** The `.env` file containing administrative credentials was served publicly as text/plain from the Apache document root.
- **Why the obvious fix is not enough:** Disabling directory listings does not stop a user from requesting the file directly by name.
- **The fix:** Stop generating the `.env` file within `/var/www/html/`. Implement an explicit Apache rule to deny HTTP access to all dotfiles as a defense-in-depth measure.

**Before (Vulnerable Apache config in infra/provision.sh):**
```Apache
<FilesMatch "^\.env$">
    ForceType text/plain
</FilesMatch>
```

**After (Hardened Apache config in hardened_provision.sh):**
``` Apache
<FilesMatch "^\.">
    Require all denied
</FilesMatch>
``` 

**Configuration or infrastructure changes:** The decoy file is completely omitted from the hardened provisioning script.  
**Migration / rollout notes:** Any credentials previously exposed in the old `.env` file must be considered compromised and rotated immediately (already executed in the hardened seed).  
**Verification:** Attempt to `curl -i http://<vm-IP>/.env`. The hardened build returns 403 Forbidden or 404 Not Found.
**Regression test:** test_env_file_accessibility  
**Residual risk:** None.  
</br>  

### NB-01: Administrative Interface Discoverable via Directory Enumeration

- **The problem:** The administrative routes lacked comprehensive session validation, relying on obscurity (unlinked pages) for protection.
- **Why the obvious fix is not enough:** Moving the `/admin/` directory to a new hidden folder (e.g., `/staff-portal-xyz/`) just restarts the clock until enumeration tools find the new path.
- **The fix:** Centralize administrative session validation into a single required helper function require_admin_session() loaded at the top of every restricted page.

**Before (Vulnerable www/admin/dashboard.php):**
``` PHP
if ( !isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header('Location: index.php');
    exit;
}
```

**After (Hardened hardened/www/includes/admin-auth.php):**
``` PHP
function require_admin_session(SQLite3 $db): array {
    if (empty($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
        header('Location: index.php');
        exit;
    }
    // Verifies admin still exists in DB and fetches role data
    $stmt = $db->prepare('SELECT id, username, name, number, salary, department FROM admins WHERE id = :id LIMIT 1');
    // ... execution
    return $admin;
}

```
Every admin script (`dashboard.php`, `edit-marks.php`) now opens with:
```php
require_once __DIR__ . '/../includes/admin-auth.php';
$admin = require_admin_session($db);
$adminDepartment = $admin['department'];
```

**Configuration or infrastructure changes:** None.  
**Migration / rollout notes:** None.  
**Verification:** Attempt to access `/admin/dashboard.php` without logging in. The hardened build immediately redirects to the login page without exposing restricted content.  
**Regression test:** test_admin_auth_redirection  
**Residual risk:** Administrative panels remain exposed to the public internet. Defense in depth suggests placing them behind a VPN or internal network segment.  
</br>  

## 4. Summary Table
ID | Fix Summary | Code Location | Verification Command | Regression Test 
-|-|-|-|-
NB-05 | Replace concatenation with parameterized query. | hardened/www/admin/edit-marks.php | curl -s "http://<IP>/admin/edit-marks.php?search=' OR '1'='1" | test_admin_search_sqli_rejection
NB-06 | Remove file_get_contents and strict-match DB IDs. | hardened/www/admin/edit-marks.php | curl -s "http://<IP>/admin/edit-marks.php?id=/etc/passwd" | test_admin_lfi_rejection
NB-04 | Enforce department scope via DB WHERE clauses. | hardened/www/includes/student-access.php | Test out-of-department student ID modification via POST. | test_admin_cross_department_authorization
NB-03 | Apply lockout table tracking and password_hash. | hardened/www/includes/login-throttle.php | Send 6 bad login POST requests and observe lockout message. | test_admin_login_rate_limiting
NB-02 | Remove .env and deny dotfiles in Apache config. | hardened/infra/hardened_provision.sh | curl -I "http://<IP>/.env" | test_env_file_accessibility
NB-01 | Apply centralized session DB verification. | hardened/www/includes/admin-auth.php | curl -I "http://<IP>/admin/dashboard.php" | test_admin_auth_redirection  
</br>  

## 5. Fix Ordering

When applying these fixes to production systems, sequence them based on exploitability and independence:
1. **NB-05 (SQLi) & NB-06 (LFI):** Remediate immediately. These are Critical, zero-authentication-dependency data/file extraction vectors.
2. **NB-02 (.env Exposure):** Remediate immediately. Close the credential leakage stopping attackers from bypassing authentication.
3. **NB-03 (Auth/Spray):** Apply rate limiting and credential hashing.
4. **NB-04 (Authorization):** Enforce data access scoping on the backend.
5. **NB-01 (Session Centralization):** Standardize the routing protection.  
</br>  

## 6. Regression Test Suite Guide

To ensure these vulnerabilities do not silently return in future commits, an automated HTTP test suite runs against the application endpoints.
- **Execution:** Run the test suite via the CI/CD pipeline against the deployed container.
- **Success Criteria:** Every test asserting vulnerability absence (e.g., expecting a 403 or empty data set instead of a 200 or leaked data) must pass.
- **Failure Protocol:** If a test fails, the deployment pipeline must block the build until the endpoint logic is corrected to pass the assertion. The exact same test suite is run against the vulnerable build, where it is expected to fail entirely, proving the tests are properly calibrated.
