# Northernbridge College Portal — Learning Objectives & Real-World Impact

Six stages. Each teaches one vulnerability class, what it demonstrates
in the lab, and how the same mistake affects a real system.

> Fictional lab data only. No real credentials, targets, or working
> payloads. Injection examples are shape-only.  
</br>

## ① Hidden routes are not access control

**Concept.** An unlinked page is still a public page if the server answers it.

**Lab demonstration.** `/admin/` is not in the navigation, not in the sitemap, and not in public HTML — yet it returns a login form to any request.

**Learning outcomes.**
- Enumerate a web target and distinguish a real route from a branded 404.
- Explain why obscurity is not a security control.
- Judge whether a server behaviour is a control or a convenience.

**Real-world impact.** A university HR portal at `/staff/` linked only from the intranet is still reachable from the public internet. Every credential-guessing attempt lands on the login page, and everything behind it sits behind one password.

**Remediation.**
- Enforce authentication and authorisation on every staff route, server-side.
- Add IP allow-listing or mTLS for admin paths.
- Verify by requesting the route unauthenticated and confirming a redirect, not a 200.  
</br>  

## ② Configuration files must not be web-accessible

**Concept.** A config file served over HTTP is a credential leak.

**Lab demonstration.** `/.env` is served as `text/plain` with HTTP 200, listing twelve fictional pairs. One is valid. Wrong pairs return the same generic message; no rate limit exists by design.

**Learning outcomes.**
- Find a config file a web server should not serve.
- Test a credential list systematically instead of stopping at the first failure.
- Explain why a generic failure message is correct behaviour.

**Real-world impact.** A `.env` in a web root exposes the database password and third-party keys. Scope of damage is set by what the leaked key can do, not by what it was intended for. Discovery usually comes from the third party, not the owner.

**Remediation.**
- Keep config outside the web root.
- Block dotfiles and common config names at the web server.
- Store secrets in a manager; rotate anything exposed.
- Related: never commit `.env` to Git.  
</br>  

## ③ Authentication is not authorisation

**Concept.** A successful login does not mean the account should have that access.

**Lab demonstration.** After a successful spray, the player lands on `/admin/dashboard.php` with no second challenge. Nothing about the account changes — the boundary was crossed the moment the login succeeded.

**Learning outcomes.**
- Distinguish authentication from authorisation.
- Explain that a login is only as strong as the credential behind it.
- Judge whether a session reflects a properly scoped role.

**Real-world impact.** A contractor portal using one shared department account makes every privileged action unauditable. Login logs show *someone* logged in, never *who*, so suspicious behaviour cannot be attributed.

**Remediation.**
- One account per person; no shared admin accounts.
- Enforce least privilege on the role, not just the pages.
- Log the identity behind every privileged action.
- Related: “remember me” cookies that survive password rotation.  
</br>  

## ④ UI restrictions are not authorisation

**Concept.** A limit shown in the interface is not a limit enforced by the server.

**Lab demonstration.** The default record view shows five `NB-*` rows from the admin's own department. The moment a search term is supplied, the department clause disappears. The player's `NC-*` record exists but is invisible by default.

**Learning outcomes.**
- Tell a visible limit apart from a server-enforced one.
- Explain why a restriction applied to one query branch is not a restriction.
- Judge a “you can only see X” claim by checking every path that returns data.

**Real-world impact.** A tutor's marks view correctly shows only their class — the search box on the same page does not. Entire student datasets, across all years, sit behind one input.

**Remediation.**
- Enforce authorisation in the data layer on every query path.
- If the UI hides it, the server must refuse it.
- Centralise the check so new paths cannot silently skip it.
- Related: role checks in templates instead of controllers.  
</br>  

## ⑤ User input must not become query logic

**Concept.** Concatenating input into SQL lets the user rewrite the query.

**Lab demonstration.** `edit-marks.php` concatenates `$search` into the SQL string. The default branch is parameterised; the search branch is not. The trailing `NB-%` restriction sits on one line and can be neutralised with a comment. A `UNION` with the correct column count (8) returns rows from any table, including `compliance_notes`.

**Learning outcomes.**
- Recognise a concatenated query and explain how input alters its logic.
- Build a `UNION`-shaped input when the column count is known.
- Read `sqlite_master` to enumerate a schema.
- Explain why patching only some branches is not a patch.

**Real-world impact.** An order-search box built by concatenation returns the entire customer table — hashes, addresses, everything — and then anything else the database process can read. Detection often comes late, and sometimes not at all.

**Remediation.**
- Prepared statements everywhere, in every branch.
- Apply the rule to all query paths, not just the default.
- WAF as defence in depth, never as the primary control.
- Related: ORM builders accepting raw fragments; `ORDER BY`/`LIMIT` from user input.  
</br>  

## ⑥ User input must not become a file path

**Concept.** User-controlled paths let the attacker read files the process can access.

**Lab demonstration.** `edit-marks.php` treats `id=` as a student ID when it does not start with `/`, and as a filesystem path when it does — no allowlist, no directory restriction. The path leaked in the previous stage is read because the web process is `www-data`.

**Learning outcomes.**
- Recognise an input treated as a filesystem path and judge the blast radius.
- Chain one vulnerability into another (SQLi → clue → LFI).
- Explain why an allowlist, not a blocklist, is the correct control.
- Explain why least-privilege filesystem permissions limit damage.

**Real-world impact.** An invoice-download endpoint that accepts a filename reads source, config, and other tenants' data. Plain file reads look identical to legitimate ones in the access log, so a WAF may be the only detector.

**Remediation.**
- Never let input determine a filesystem path. Use an allowlist or opaque IDs.
- Reject absolute paths and traversal as a secondary control.
- Run the web process with least privilege; keep secrets outside the web root.
- Related: image loaders accepting URLs; “download by name” endpoints.  
</br>  

## Summary

| # | Vulnerability class | Real-world analogue | Fix in one line |
|---|---|---|---|
| ① | Unlinked route treated as hidden | Publicly reachable staff portal | Server-side auth on every route |
| ② | Exposed configuration file | `.env` in a web root | Move secrets out; block dotfiles |
| ③ | Authentication vs authorisation | Shared contractor account | One account per person; audit identity |
| ④ | UI-only restriction | Tutor sees every class | Enforce scope in every query path |
| ⑤ | SQL injection | Order-search box | Prepared statements in every branch |
| ⑥ | Local file inclusion | Invoice-by-name download | Path allowlist + least-privilege FS |  
</br>  

## Where these skills belong

- Authorized penetration testing under signed scope.
- Application security reviews within a development lifecycle.
- Bug-bounty programmes where the target is in scope.
- Internal red-team exercises under a rules-of-engagement document.
- Security education and CTFs on isolated infrastructure.

Techniques shown here are only appropriate in environments you are
explicitly authorized to test.  
</br>  

## Further reading (vendor / standards-body only)

- [SQLite](https://www.google.com/search?q=prepared+statements+and+SQL+injection+guidance.&oq=prepared+statements+and+SQL+injection+guidance.&gs_lcrp=EgZjaHJvbWUyBggAEEUYOTIHCAEQIRigATIHCAIQIRiPAjIHCAMQIRiPAtIBBzM0MWowajeoAgCwAgA&sourceid=chrome&source=chrome.ob&ie=UTF-8) — prepared statements and SQL injection guidance.
- [PHP](https://search.brave.com/search?q=PDO+prepared+statements+and+SQLite3+in+the+official+manual.&conversation=09a98555ad410d1f94b12b59ffea79d312c1) — PDO prepared statements and SQLite3 in the official manual.
- [Apache HTTP Server](https://search.brave.com/search?q=Apache+HTTP+Server+%E2%80%94+%60FilesMatch%60%2C+%60ForceType%60%2C+%60Require%60%2C+access+control&conversation=09a948465b2bf7977648c53ac5f80f9a24d9) — `FilesMatch`, `ForceType`, `Require`, access control.
- [OWASP](https://search.brave.com/search?q=OWASP+%E2%80%94+*SQL+Injection+Prevention*+and+*Path+Traversal*+cheat+sheets.&conversation=09a9f030159db1c049560e4e159ae87cf81b) — *SQL Injection Prevention* and *Path Traversal* cheat sheets.
- [CWE](https://search.brave.com/search?q=CWE+%E2%80%94+CWE-89%2C+CWE-22%2C+CWE-548%2C+CWE-798.&conversation=09a98d8afd4b97b3e2bff8fa4a7cd1ff0d1a) — CWE-89, CWE-22, CWE-548, CWE-798.
