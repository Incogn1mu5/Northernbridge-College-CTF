# CTF Design & Challenge Flow

## 1. Overview

The Northernbridge College CTF is a progressive investigation through a
fictional college portal. The player starts as a normal student and
gradually discovers weaknesses in the portal, with each stage teaching
one concept at a time.

```
College Website
      │
      ▼
Student Registration
      │
      ▼
Student Login
      │
      ▼
Student Profile and marks
      │
      ▼
Directory Enumeration
      │
      ▼
Discover .env file
      │
      ▼
Discover hidden /admin Portal
      │
      ▼
Login as admin
      │
      ▼
Admin Dashboard
      │
      ▼
Limited Student Records
      │
      ▼
Unsafe Search
      │
      ▼
SQL injection to break restriction
      │
      ▼
Player's Student Record
      │
      ▼
Dump full database using SQLi
      │
      ▼
Follow compliance notes clue to find final Flag 04
```
</br>  

## 2. Player Starting Point

1. Player starts at the public Northernbridge College homepage,
   presented as a normal fictional college portal.
2. Primary student functionality: registration, login, profile,
   examination marks.
3. The administration portal is deliberately absent from normal
   student navigation.  
</br>

## 3. Exercise Stages & Flags (authoritative table)

| # | Stage | Where it happens | Flag | Location |
|---|---|---|---|---|
| 1 | Discover the hidden admin portal | `/admin/` is unlinked; brute-forceable | `NCC{Dis.....}` | On the admin login page |
| 2 | Password spraying | Decoy `/var/www/html/.env` with 12 fictional `username:password` pairs; only `helen.carter:Winter2026!` is valid | (evidence = login + Apache access log) | — |
| 3 | Access admin dashboard | `/admin/dashboard.php` | `NCC{Log.....}` | On the admin dashboard |
| 4 | Restricted clerk view | `www/admin/edit-marks.php`, default (no-search) view, scoped to admin's own department via `NB-%` + `:department` | `NCC{Exp.....}` | Under the restricted student-record view |
| 5 | Database exfiltration | SQL injection via `search=` on `edit-marks.php` → dump all tables → read the compliance note | Clue pointing to `/opt/northernbridge/flag.txt` | In the search field, parameter `search=` |
| 6 | Final flag | Local File Inclusion via `id=` on `edit-marks.php` | `NCC{...}` | Filesystem `/opt/northernbridge/flag.txt`, **not** in the database |

The final (stage 6) flag is created by `infra/provision.sh` with a
random token per deployment, stored `root:www-data` mode `0640`. The
literal value never appears in Git or in any database table (`Flag_04`
was removed from the `flags` table for this reason).  
</br>  

## 4. Stage-by-Stage Design

### Stage 1 — Discover the Administration Portal

**Objective:** Discover the hidden administration area.

**Flow:**
- Player registers a student account, receives generated credentials.
- After logging in, views profile and exam results.
- Seeded marks include a failing Python result; the "Reassessment"
  option errors out.
- Through directory enumeration, player discovers `.env` and the
  hidden `/admin` route.
- Visiting `/admin/` reveals **Flag 01** (`NCC{Dis.....}`)
  on the admin login page.

**Technical implementation:**
- `/admin/` is unlinked and must be discovered via enumeration.
- The only hint in served HTML is the comment `<!-- backup: /.env -->`
  on `www/admin/index.php` — must never appear on any public page.

**Lesson:** An unlinked or hidden route is not a security control. A
route absent from navigation can still be discovered.

---

### Stage 2 — Exposed Administrator Credentials

**Objective:** Use the fictional admin credentials exposed via `.env`
to authenticate.

**Flow:**
- Player discovers `.env`, finds fictional admin credentials.
- Returns to the admin login page and authenticates.
- On success, **Flag 02** (`NCC{Log.....}`) appears on the
  admin dashboard.

**Technical implementation:**
- `infra/provision.sh` writes `.env` to `/var/www/html/.env` on every
  provision, labelled **"LAB ONLY — FICTIONAL CREDENTIALS."**
- Exactly 12 `username:password` pairs; exactly **one**
  (`helen.carter:Winter2026!`) matches the seeded `admins` row (the
  provisioner re-syncs this every run, so pre-existing databases
  converge too).
- All other pairs fail with the same generic message —
  **"Invalid administrator username or password."** — deliberately, to
  avoid user enumeration.
- Served as `text/plain` via `<FilesMatch "^\.env$">` +
  `ForceType text/plain` (needed because Apache treats the
  extensionless hidden filename `.env` as typeless — `AddType` alone
  wouldn't match it). Returns HTTP 200, not blocked.
- **LAB ONLY — no throttling:** no lockout/rate-limit/CAPTCHA by
  design. Every spray attempt is one line in the Apache access log
  (`northernbridge_access.log`).

**Lesson:** A `.env` file is not an access-control mechanism and must
not be publicly accessible.

---

### Stage 3 — Explore the Limited Student Records (Clerk View)

**Objective:** Understand the normal (restricted) default view of the
admin student-record page, before exploiting anything.

**Flow:**
- After login, player reaches the admin dashboard and the marks editor
  (`www/admin/edit-marks.php`).
- With no search term entered, the default view shows only **5** seeded
  `NB-*` records, all from the signed-in admin's own department.
- Player should observe — not yet exploit — what's visible, what
  fields are shown, and that the set is intentionally small/limited.
- **Flag 03** (`NCC{Exp.....}`) is tied to this stage.

**Technical implementation (default view — the only place the
department restriction is actually enforced):**
```php
// Normal/default view (no ?search= supplied).
$stmt = $db->prepare("
    SELECT s.student_id, s.first_name, s.last_name, s.department,
           m.math, m.cpp, m.python, m.graphics
    FROM students s
    LEFT JOIN marks m ON s.student_id = m.student_id
    WHERE s.student_id LIKE 'NB-%'
        AND s.department = :department
    ORDER BY s.student_id
    LIMIT 5
");
$stmt->bindValue(':department', $adminDepartment, SQLITE3_TEXT);
```
- This is a safe, parameterized query — `:department` is properly
  bound, not concatenated.
- **This is the only code path where department scoping is real.** The
  moment `search` is non-empty, this branch is skipped entirely (see
  Stage 5) — so the "clerk can only see their own department" rule is
  enforced for exactly one condition (empty search box) and nowhere
  else. Framed plainly: the department boundary is a **visual/default
  restriction**, not a genuine access-control boundary.

**Lesson:** Application-level restrictions must actually enforce the
intended data boundary, not just apply to the default/empty state of
the UI.

---

### Stage 4 — Investigate the Unsafe Search → SQL Injection (`search=`)

**Objective:** Identify the weakness in `edit-marks.php`'s search and
use it to locate the player's own record.

**Flow:**
- Normal search restricts results to seeded **`NB-*`** records.
- Player registrations use **`NC-*`** IDs — so a player's own record is
  invisible to normal search by design:
  - `NB-*` → seeded records → searchable normally
  - `NC-*` → registered CTF players → hidden from normal search
- The implementation concatenates `search` directly into SQL with no
  parameterization.
- Player should: observe normal behavior → notice input affects the
  query → test unexpected input → determine the `NB-%` restriction
  (and, incidentally, the department restriction, which was never
  enforced here to begin with) can be bypassed → locate their own
  `NC-*` record → obtain their student ID → open/modify their marks.

**Player record format:**
```
NC-<initials><year>-<random-suffix>
```
e.g. `NC-AB26-1234`. Seeded marks include a deliberately low Python
score.

**Technical implementation — the actual vulnerable branch:**
```php
// INTENTIONAL CTF SQL INJECTION — triggered whenever $search !== ''
$query = "
    SELECT s.student_id, s.first_name, s.last_name, s.department,
           m.math, m.cpp, m.python, m.graphics
    FROM students s
    LEFT JOIN marks m ON s.student_id = m.student_id
    WHERE
        (
            s.first_name LIKE '%$search%'
            OR s.last_name LIKE '%$search%'
            OR s.student_id LIKE '%$search%'
            OR s.department LIKE '%$search%'
        ) AND s.student_id LIKE 'NB-%' ORDER BY s.student_id
";
$result = $db->query($query); // raw, unparameterized
```
- `$search` is concatenated directly (`%$search%`) with **no**
  department clause at all in this branch — confirming department
  scoping simply does not exist once search is used.
- The restriction tail (`AND s.student_id LIKE 'NB-%' ORDER BY
  s.student_id`) is kept on one line on purpose: SQLite's `--`/`/*`
  comment to end-of-line, so a `/*` payload cleanly kills the `NB-%`
  restriction + ordering together.
- Working payload shapes:
  ```text
  ') OR `VALUE`=`VALUE` /*
  ') UNION SELECT <COLUMN 01>,<COLUMN 02> ...,<COLUMN 08> FROM sqlite_master /*
  ') UNION SELECT <COLUMN 01>,<COLUMN 02>,<COLUMN 03>,NULL,NULL,NULL,NULL,NULL FROM <TABLE_NAME> /*
  ```
  (Each `LIKE` is `'%$search%'`, so `')` closes the quoted literal and
  the surrounding paren group before the `UNION`.)
- Column count for `UNION` payloads is **8**:
  `student_id, first_name, last_name, department, math, cpp, python,
  graphics`. Unioned rows land in those fixed output columns.
- Failure path is safe: `try/catch` + "Student not found." — SQL
  errors are never printed.
- The vulnerability is confined to the fictional SQLite database — no
  host-OS exploitation is in scope for this stage.

**Lesson:** Concatenating user input into SQL lets an attacker alter
the application's intended query logic — and here, it also happens to
be the *only* place a boundary (department) was ever meant to apply,
and it still isn't enforced.

---

### Stage 5 — Database Exfiltration

**Objective:** Use the Stage 4 injection to dump the database and find
the clue to the final **Flag 04**.

**Flow:**
- Using the `UNION SELECT ... FROM sqlite_master` and follow-up
  payloads, the player enumerates and dumps all tables:
  `students`, `courses`, `marks`, `faculty`, `compliance_notes`,
  `admins`, `flags`.
- `compliance_notes` contains the bridging hint:
  > Full audit log archived at `/opt/northernbridge/flag.txt`
- This hint is the bridge from the database dump to the Stage 6
  filesystem flag.

**Lesson:** Data disclosed through injection can itself be the
reconnaissance step that enables a second, unrelated vulnerability
class (here, LFI) further down the chain.

---

### Stage 6 — Final Flag 04 via LFI (`id=`)

**Objective:** Exploit the Local File Inclusion on `id=` to read
`/opt/northernbridge/flag.txt` and obtain the final `Flag 04`.

**Flow:**
- Player supplies the path found in Stage 5 as `?id=/opt/northernbridge/flag.txt`.
- **Flag 04 / final flag** (`NCC{...}`) is returned.

**Technical implementation — the LFI branch, and `id`'s dual purpose:**
```php
$edit_id = $_GET['id'] ?? '';

if ($edit_id !== '' && str_starts_with($edit_id, '/')) {
    // LFI: any absolute path is read directly, no allowlist,
    // no restriction to a safe directory.
    if (is_file($edit_id) && is_readable($edit_id)) {
        $file_contents = file_get_contents($edit_id);
    } else {
        $file_read_error = 'Unable to read requested file.';
    }
} elseif ($edit_id !== '') {
    // Legitimate feature: look up a single student by ID.
    // This path IS parameterized/safe — id is NOT a SQLi vector.
    $stmt = $db->prepare(
        'SELECT s.student_id, s.first_name, s.last_name, s.department,
                m.math, m.cpp, m.python, m.graphics
         FROM students s
         LEFT JOIN marks m ON s.student_id = m.student_id
         WHERE s.student_id = :student_id
         LIMIT 1'
    );
    $stmt->bindValue(':student_id', $edit_id, SQLITE3_TEXT);
    $result = $stmt->execute();
    $selected_student = $result ? $result->fetchArray(SQLITE3_ASSOC) : null;
}
```
- `id` has exactly two behaviors, selected purely by whether the value
  starts with `/`:
  - **Starts with `/`** → treated as an absolute filesystem path and
    read with no validation whatsoever → **LFI**.
  - **Does not start with `/`** → treated as a `student_id` and looked
    up via a properly parameterized prepared statement → safe, **not**
    a SQL injection vector.
- A commented-out block in the source shows an available (but
  deliberately disabled) fix that would additionally scope this lookup
  to `NC-%` IDs or the admin's own department:
  ```php
  /* AND ( s.student_id LIKE 'NC-%' OR s.department = :department ) */
  ```
  This confirms the department boundary was *designed* to be
  enforceable here too, but was intentionally left off — reinforcing
  that the only live department check anywhere in the app is the
  Stage 3 default view (§3 above).

**Lesson:** Sensitive information can live outside the database, in
the server's filesystem. Data disclosed via injection can reveal where
to look, and an improperly validated "read a file" code path (no
allowlist, no path restriction) turns that knowledge into direct file
disclosure. Remediation: allowlist file paths, never let user input
determine arbitrary filesystem paths, enforce least-privilege
filesystem permissions, keep sensitive files outside web-accessible
directories, and apply the same parameterization discipline to *every*
query branch, not just some.  
</br>  

## 5. Complete Challenge Chain

```
┌──────────────────────────────────────┐
│ 1. Visit Northernbridge College       │
│    Website                           │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ 2. Register Student Account          │
│    Receive generated credentials     │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ 3. Login and Open Profile            │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ 4. Perform Directory Brute-force     │
│    Discover /admin and .env file     │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ 5. Visit /admin web directory        │
│    Discover Admin Login Portal       │
└──────────────────┬───────────────────┘
                   │
         [ FLAG 01 / NCC {...}]
                   │
                   ▼
┌──────────────────────────────────────┐
│ 6. Use credentials found inside .env │
│    to login as admin                 │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ 7. Explore Admin Dashboard           │
│    Inspect limited (NB-*, own-dept)  │
│    records — default view            │
└──────────────────┬───────────────────┘
                   │
         [ FLAG 02 / NCC{...} ]
                   │
                   ▼
┌──────────────────────────────────────┐
│ 8. Investigate Student Search        │
│    (search=) — identify unsafe       │
│    query handling                    │
└──────────────────┬───────────────────┘
                   │
         [ FLAG 03 / NCC{...}]
                   │
                   ▼
┌──────────────────────────────────────┐
│ 9. SQLi via search= to bypass NB-%   │
│    Locate player's own NC-* record   │
│    and edit marks                    │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ 10. Dump database via SQLi, follow   │
│     clue inside compliance_notes     │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ 11. Exploit LFI on id= parameter     │
│     Retrieve flag.txt from system    │
└──────────────────┬───────────────────┘
                   │
         [ FLAG 04 / NCC{...} ]
                   │
                   ▼
             CTF COMPLETED
```
</br>  

## 6. Database Schema (tables involved)

`students`, `courses`, `marks`, `faculty`, `compliance_notes`,
`admins`, `flags`.  
</br>

## 7. Anti-Cheat / Design Constraints

- The literal final flag value is never stored in the SQLite database or committed to Git.
- `.env`, the database file, and the flag file are all generated at
  provision time; `.gitignore` excludes `*.db`, `.env`, and
  `www/database/`.
- Design docs (this file, `Docs/`) live outside `PORTAL_SUBDIR` and are
  never served.
- No host-OS, Vagrant, or VirtualBox exploitation, SSH attacks, real
  credentials, real student data, persistence, or lateral movement are
  part of the intended solution path.  
</br>

## 8. Intended Learning Outcomes

- **Hidden routes:** absence from navigation ≠ inaccessible.
- **Sensitive information exposure:** config files can leak secrets if
  placed web-accessibly.
- **Authorization and data boundaries:** a restriction that only
  applies to one code path (here, the empty-search default view) is
  not a real boundary — the rest of the app must honor it too.
- **SQL injection:** concatenating user input into SQL lets an
  attacker alter intended query logic.
- **Local File Inclusion:** an unvalidated "read this path" branch,
  with no allowlist or directory restriction, exposes arbitrary files.
- **Remediation:** parameterized queries *everywhere* (not just some
  branches), proper authorization checks enforced consistently, no
  secrets in web-accessible files, restricted sensitive routes,
  validated per-record access, and clear separation of user-facing
  from administrative functionality.