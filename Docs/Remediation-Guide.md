# Remediation Guide (Final)

**Target:** Northernbridge College Portal — hardened reference build
**Audience:** Developers who own this code and have never seen it before
**Companion document:** `docs/findings-report.md` (findings NB-01 – NB-06)

---

## 1. How to Use This Guide

### 1.1 Repo layout

| Variant | Location | Brought up by |
|---|---|---|
| **Vulnerable build** (unchanged) | application repo, as deployed today | `vagrant up` (default machine, `infra/provision.sh`) |
| **Hardened build** | `hardened/` | `vagrant up hardened` (explicit, `autostart: false`, `hardened/infra/hardened_provision.sh`) |

Both machines are defined in one `Vagrantfile` via two `config.vm.define`
blocks. The vulnerable machine is `primary: true` — a bare `vagrant up`
still only brings up the CTF target, unchanged. The hardened machine never
auto-starts and is provisioned, networked, and named independently
(`northernbridge-hardened` / VirtualBox name `Northernbridge-Hardened`), so
the two can run side by side without colliding.

### 1.2 What is deliberately absent from the hardened build

Two things were removed outright rather than fixed, because they have no
place in a hardened verification build at all:

- **The entire CTF flag flow.** No `flags` table, no `compliance_notes`
  table, no `$flag1`/`$flag2`/`$flag3` fetch-and-display code in
  `index.php`, `dashboard.php`, or `edit-marks.php`. The flag flow belongs
  to the vulnerable build only.
- **The decoy `.env` file.** Never written into the hardened document
  root at all — not hidden better, not moved, simply never created.

---

## 2. Ground Rules Applied Throughout

1. Every fix is server-side; nothing relies on hiding a link or a UI
   element.
2. Every admin script authenticates and authorizes itself — no script
   assumes it was only ever reached through a trusted link.
3. No SQL query is ever built by concatenating user input into a string.
   Every query is a prepared statement with bound parameters.
4. No secret-bearing file is ever placed inside the web-servable document
   root — not `.env`, not anything else.
5. No credential in the hardened build is ever a value that was exposed in
   the vulnerable build. The hardened admin password was chosen
   specifically because it has never appeared anywhere in the vulnerable
   build's seed data or decoy `.env`.
6. Obscurity (unlinked routes, unguessable paths) is never treated as a
   control — every fix below closes the underlying server-side gap, not
   just the specific path an assessor happened to find.

---

## 3. Fix Chapters

---

### NB-01 — Administrative Interface Discoverable via Directory Enumeration

**Fix:** a single shared session/authorization gate, `require_admin_session()`
in `hardened/includes/admin-auth.php`, called as the first line of real
logic in every admin script. It does two things no inline check did
reliably: it re-verifies the admin still exists in the database (not just
that a session flag is set), and it returns the full admin row — including
`department`, `number`, and `salary` — so no page re-queries it separately.

```php
// hardened/includes/admin-auth.php
function require_admin_session(SQLite3 $db): array
{
    if (empty($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
        header('Location: index.php');
        exit;
    }

    $stmt = $db->prepare('
        SELECT id, username, name, number, salary, department
        FROM admins
        WHERE id = :id
        LIMIT 1
    ');
    $stmt->bindValue(':id', $_SESSION['admin_id'] ?? null, SQLITE3_INTEGER);
    $result = $stmt->execute();
    $admin = $result ? $result->fetchArray(SQLITE3_ASSOC) : false;

    if (!$admin) {
        session_unset();
        session_destroy();
        header('Location: index.php');
        exit;
    }

    return $admin;
}
```

Every admin script (`dashboard.php`, `edit-marks.php`) now opens with:
```php
require_once __DIR__ . '/../includes/admin-auth.php';
$admin = require_admin_session($db);
$adminDepartment = $admin['department'];
```
replacing what were previously separate, inline, independently-written
session checks and admin-row lookups per file. Route existence or
discoverability is now irrelevant — every admin script enforces the same
check itself, regardless of how the request arrived.

**Verification:** an unauthenticated request to any admin script redirects
to `index.php`, never returns admin content.

---

### NB-02 — Sensitive Credentials Exposed in Public Configuration File

**Fix:** no secret-bearing file is ever placed in the hardened document
root — not relocated, not relabeled, simply never created. The hardened
build needs no runtime config file at all: `db.php`'s database path is a
constant, and the one admin credential pair is generated directly into the
database by the provisioning script (see NB-03), never written to disk as
a flat file at any point.

**Apache vhost (`hardened/infra/hardened_provision.sh`):**
```apache
# Block all dotfiles (.env, .git, etc.) from being served.
<FilesMatch "^\.">
    Require all denied
</FilesMatch>
```
This replaced an earlier attempt that had the right intent but a broken
regex (`^\. $`, which matches nothing real) and an invalid directive
(`ForceType all denied`, not valid Apache syntax) — both were corrected so
the rule actually blocks every dotfile, not just the one filename an
assessor happened to find.

**Verification:** `curl -i http://<hardened-vm>/.env` → `404`/`403`; same
for any other dotfile pattern.

---

### NB-03 — Weak Authentication Controls Enable Password Spraying

**Fix, three parts together:**

**(a) Passwords are hashed, not compared in plaintext.** The `admins`
table column is `password_hash`, not `password`, and `index.php` verifies
with `password_verify()`:
```php
// hardened/www/admin/index.php
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
(Everything is wrapped in the `REQUEST_METHOD === 'POST'` check — an
earlier draft of this file computed `$clientKey` from `$username` *before*
it was ever read from `$_POST`, which ran on every page load including
plain GETs. That stray line was removed.)

**(b) Throttling and lockout**, `hardened/includes/login-throttle.php`:
```php
const LOGIN_MAX_ATTEMPTS    = 5;
const LOGIN_LOCKOUT_SECONDS = 300;

function login_is_locked_out(SQLite3 $db, string $key): bool { /* ... */ }
function login_record_failure(SQLite3 $db, string $key): void { /* ... */ }
function login_clear_attempts(SQLite3 $db, string $key): void { /* ... */ }
```
backed by a new table:
```sql
CREATE TABLE IF NOT EXISTS login_attempts (
    attempt_key  TEXT PRIMARY KEY,
    attempts     INTEGER NOT NULL DEFAULT 0,
    last_attempt INTEGER NOT NULL
);
```

**(c) A fixed, known, admin credential, hashed automatically
at provisioning time** — not a fresh random password every build (hard to
test against), and a value copied from the vulnerable build's exposed
`.env`/seed data (exactly same as early draft of the provisioning
script made by reusing `'Winter2026!'`, the vulnerable build's actual
leaked password — hashed and stored in to the database:
```bash
# hardened/infra/hardened_provision.sh — step [6/7], runs AFTER schema
# creation (step [5/7]), not before — an earlier draft had this backwards,
# which failed on a fresh VM because the admins table didn't exist yet.
ADMIN_USERNAME="helen.carter"
ADMIN_DEPARTMENT="Information Technology"
ADMIN_PASSWORD="Winter2026!"

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
`hardened_seed.sql` defines the `admins` table's **schema only** — no
`INSERT` for the admin row lives there. An earlier draft had *both*
`seed.sql` and this PHP step each inserting the same username, which is a
conflict by construction (`INSERT OR IGNORE` means whichever ran first
silently wins and the other does nothing) — and the `seed.sql` copy
additionally put the plaintext leaked password directly into the
`password_hash` column, which isn't a hash at all and would never have
verified against any password. There is now exactly one place the admin
account is created.

**Verification:** 6 consecutive failed logins → 6th rejected regardless of
correctness; no row in `admins` matches a plaintext-password pattern;
`password_verify()` succeeds for the known seeded password.

---

### NB-04 — Inadequate Authorization Controls in Restricted Record View

**Final agreed model** (narrower than the default dashboard view, and
narrower than search — three distinct, deliberate scopes, not one rule
applied everywhere):

| Feature | Scope |
|---|---|
| Dashboard default roster | Admin's own department, `NB-*` only |
| Search (by name or ID) | **Unrestricted** — any department's `NB-*`, plus `NC-*` (see NB-05) |
| Open/edit a specific record (`?id=`) | `NC-*` (any) **or** `NB-*` in the admin's own department only |

The "open/edit" scope is enforced by a single shared helper,
`hardened/includes/student-access.php`, rather than by the dashboard's and
edit-marks' own independent copies of the rule — the original codebase had
exactly this restriction written out already, just commented out and
therefore never active:
```php
function fetch_authorized_student(SQLite3 $db, string $studentId, string $adminDepartment): ?array
{
    $stmt = $db->prepare('
        SELECT
            s.student_id, s.first_name, s.last_name, s.department,
            m.math, m.cpp, m.python, m.graphics
        FROM students s
        LEFT JOIN marks m ON s.student_id = m.student_id
        WHERE s.student_id = :student_id
          AND (
                s.student_id LIKE \'NC-%\'
                OR s.department = :department
              )
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
Deliberately, this means **search can surface a record an admin is not
permitted to open** — e.g. another department's `NB-*` student shows up
in a search result, but clicking "Edit Marks" on it is denied by this
helper. That split is intentional, not a gap: "finding" and "editing" are
different operations with different legitimate scopes.

**Verification:** a clerk from department A requesting a known
department-B student via `?id=` gets "Student not found"; the same clerk
can still find that student through search.

---

### NB-05 — SQL Injection in Administrative Search Functionality

**Fix:** parameterized query, with the search scope matching the model
above — no `'NB-%'` restriction, no department restriction, since search
is deliberately the broad-lookup tool (`id=` handles the narrow,
authorization-enforcing case):
```php
// hardened/www/admin/edit-marks.php — search branch
$likePattern = '%' . $search . '%';
$stmt = $db->prepare('
    SELECT
        s.student_id, s.first_name, s.last_name, s.department,
        m.math, m.cpp, m.python, m.graphics
    FROM students s
    LEFT JOIN marks m ON s.student_id = m.student_id
    WHERE
        s.first_name LIKE :pattern
        OR s.last_name LIKE :pattern
        OR s.student_id LIKE :pattern
        OR s.department LIKE :pattern
    ORDER BY s.student_id
');
$stmt->bindValue(':pattern', $likePattern, SQLITE3_TEXT);

$result = $stmt->execute();
if ($result) {
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $students[] = $row;
    }
}
```
`$search` is bound as a parameter, never concatenated into SQL text — no
input can alter the query's structure regardless of content. The default
(no search term) view is untouched from its original, already-correct
form: parameterized, `'NB-%'`-filtered, department-scoped, `LIMIT 5`.

**A note on how this was arrived at:** an earlier draft added department
scoping to the search branch, modeled on the default view. That was
corrected after confirming the intended behavior directly — search is
meant to be the broad tool, with authorization enforced only at the point
of opening a record (NB-04), not at the point of finding one.

**Verification:** a structural-alteration test input returns no change in
result-set shape (confirms parameterization); a search by name/ID
correctly returns matches from other departments and from `NC-*` records
(confirms the intended scope, not an accidental restriction).

---

### NB-06 — Local File Inclusion Through Unvalidated File Path Parameter

**Fix:** the file-path branch of the `id` parameter was deleted entirely,
not filtered or guarded further. There is no `file_get_contents()`,
`readfile()`, `fopen()`, or `str_starts_with($edit_id, '/')` anywhere in
the hardened `edit-marks.php` — confirmed by grep across the full file,
not just visual inspection. `$edit_id` is used for exactly one thing: as
the argument to `fetch_authorized_student()` above.

An earlier draft of this fix removed the LFI code in one place in the file
but left a second, near-identical copy of it elsewhere (plus the removed
code had briefly been replaced by a misplaced copy of the search-query fix
pasted into the wrong branch, which did nothing useful and also didn't
close the vulnerability). The final version has neither problem: a single
`grep -n "file_get_contents\|str_starts_with"` across the file returns no
matches.

**Verification:** `curl -b "<session>" "http://<hardened-vm>/admin/edit-marks.php?id=/etc/hostname"` returns the normal "Student not found" response, with no file content anywhere in the body.

---

## 4. Summary Table

| ID | Fix | Where | Key correction made during implementation |
|---|---|---|---|
| NB-01 | Shared `require_admin_session()` gate on every admin script | `includes/admin-auth.php` | Earlier drafts `require`'d the file but never called it — old inline checks were still live |
| NB-02 | No secret file ever placed in docroot; dotfiles blocked at vhost | `hardened_provision.sh` (vhost block) | Vhost regex/directive were initially broken (`^\. $`, invalid `ForceType all denied`) |
| NB-03 | Hashed passwords, throttling/lockout, fixed non-leaked seed credential, hash computed automatically at provision time | `admin/index.php`, `includes/login-throttle.php`, `hardened_provision.sh` | `$username` read-before-POST-check bug; admin-seed step ran before schema existed; seed credential briefly reused the vulnerable build's leaked password in two different places |
| NB-04 | `fetch_authorized_student()` — `NC-*` any, `NB-*` own department only, for direct open/edit | `includes/student-access.php` | Confirmed deliberately narrower than search, not equal to it |
| NB-05 | Parameterized search query, intentionally unrestricted by department/prefix | `admin/edit-marks.php` | An interim version wrongly added department scoping to search; corrected to match the agreed model |
| NB-06 | File-path branch of `id=` deleted entirely | `admin/edit-marks.php` | Two separate leftover copies of the LFI code (plus a misplaced search-fix paste) were found and removed in review before the final clean version |

**Cross-cutting, not tied to one finding:** all CTF flag code (`flags`
table, `compliance_notes` table, `$flag1`/`$flag2`/`$flag3` fetch/display)
removed from `index.php`, `dashboard.php`, `edit-marks.php`, and
`hardened_seed.sql` — the flag flow belongs to the vulnerable build only.

---

## 5. Supporting Infrastructure Fixes

These aren't findings in `docs/findings-report.md`, but were necessary to
actually build and run the hardened artifact correctly, and are part of
the same body of work:

- **`Vagrantfile`** restructured from one implicit machine into two
  explicit `config.vm.define` blocks (`vulnerable`, `primary: true`;
  `hardened`, `autostart: false`), each with its own hostname, VirtualBox
  VM name, dev-mode synced-folder source (`./www` vs `./hardened/www`),
  and provisioner path — so `vagrant up hardened` is possible at all and
  never collides with or auto-starts alongside the CTF target.
- **Provisioning step order** in `hardened_provision.sh` corrected so
  database/schema creation runs before admin-account seeding, not after.
- **Bridged-adapter DHCP race** — the original `sleep 2` before checking
  for a bridged IP was a fixed-time guess, and `ubuntu/jammy64`'s
  cloud-init netplan config frequently doesn't cover the second NIC
  Vagrant's `public_network` adds at all. Fixed with an explicit
  all-interfaces DHCP netplan override plus a polling loop instead of a
  single sleep.
- **IP/access report now re-runs on every boot**, not just the first
  provision — split into its own `run: "always"` shell provisioner
  (`infra/report-access.sh`) so `vagrant halt` → `vagrant up` still shows
  current NAT/Bridge addresses, since Vagrant's normal provisioners only
  execute once.
- **Startup banner** de-duplicated (Vagrant evaluates the Vagrantfile
  multiple times per invocation, re-running any bare `puts`) and split
  into mode-correct text per machine: `CHALLENGE MODE` vs `DEVELOPMENT
  MODE` for the vulnerable build, `Hardened Build` vs `Hardened -
  DEVELOPMENT MODE` for the hardened one.
