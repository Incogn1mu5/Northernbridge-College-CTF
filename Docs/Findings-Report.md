# Security Findings Report

**Target:** Northernbridge College Portal (fictional web application)  
**Engagement type:** Internal application security assessment — authorized lab environment  
**Report classification:** Internal — reviewer / engineering lead  

---

## 1. Executive Summary

Northernbridge College Portal is a fictional web application providing a student-facing
portal (registration, login, profile, examination marks) and an admin-portal
(staff login, student record search, marks management). An application security
assessment was performed against a single, isolated instance of the portal running in
a local, non-production virtual machine.

The assessment identified **six findings**, ranging in severity from **Low** to
**Critical**. Taken together, the findings describe a complete compromise path: an
unauthenticated visitor can discover the administrative interface, recover valid staff
credentials from an exposed configuration artifact, log in without being rate-limited,
bypass the intended scope of the staff record view, extract the entire student
database through an injectable search field, and finally read arbitrary files on the
underlying server through the same interface.

No single finding is the root of the problem. The portal fails at several independent
layers — discovery, configuration hygiene, authentication, authorization, input
handling, and file access — and an attacker only needs to walk through them in
sequence. The overall risk to the system as assessed is rated **Critical**, driven
primarily by the SQL injection and local file inclusion findings, both of which allow
an attacker to retrieve data and files well beyond anything the application's own
access controls were intended to permit.

**Recommended action:** Treat the two Critical findings (SQL injection, local file
inclusion) as blocking — they must not reach a production-equivalent build under any
circumstances. The High findings (credential exposure, weak authentication) should be
treated as equally urgent in practice, since they are the mechanism by which an
attacker reaches the administrative interface that the Critical findings sit behind.
The Medium and Low findings should be fixed in the same pass, since both contribute to
the overall attack chain even though neither is independently severe.

This report describes what was found, how it was observed, and what must change. It
does not include exploit payloads, credential values, or any data that would make the
findings directly reusable against a system the reader is not authorized to test.

--- 

## 2. Scope and Method

### 2.1 Scope

**In scope:**
- The Northernbridge College Portal web application (student-facing pages and the administrative interface), as deployed on a single, isolated virtual machine reachable only on a private, non-routed network segment.
- The application layer only: routing, authentication, authorization, input handling, database queries, and file-access logic reachable through the web server.  
</br>  

**Out of scope:**
- The underlying host operating system, hypervisor, and any tooling used to build or provision the virtual machine.
- Any network, service, or host other than the single application instance under test.
- Denial-of-service testing, physical security, social engineering, and any testing against real people, real accounts, or real infrastructure.
- Any system not explicitly provided for this assessment.  
</br>  

### 2.2 Fictional-data disclaimer

All accounts, student records, marks, email addresses, and credential values referenced during this assessment are synthetic data generated for the purpose of the exercise. No real individual, institution, or organization is represented by this data, and none of the findings in this report describe a real-world system.  
</br>  

### 2.3 Method

The assessment followed a standard black-box-to-grey-box web application testing
approach, performed manually from a `browser`, `curl`, `directory-enumeration` tool against the application's
public HTTP interface:

1. **Reconnaissance** — manual review of all linked pages, HTML source, and automated directory/endpoint enumeration to identify unlinked functionality.
2. **Configuration review** — checking for common misconfigurations in what the web server exposes over HTTP (e.g., files that should never be served).
3. **Authentication testing** — review of the login workflow for rate limiting, lockout, and credential-handling weaknesses.
4. **Authorization testing** — comparing what a given role is shown by the UI against what the backend actually permits that role to request.
5. **Input handling review** — testing parameters that influence server-side queries or file access for injection and path-traversal behavior.
6. **Impact validation** — confirming, for each finding, what an attacker could actually obtain, scoped strictly to the fictional dataset in the lab.

All findings were identified and manually reproduced using manual assessment techniques, tactics and automated scanning tools.

--- 

## 3. Risk Rating Scale

Severity ratings in this report follow a five-level scale, broadly aligned with the
**OWASP Risk Rating Methodology** (likelihood × impact) and CVSS qualitative severity
bands, adapted to a single-application assessment:

| Rating | Criteria |
|---|---|
| **Critical** | Directly leads to full compromise of the application's data or the underlying server, with low attacker effort and no special access required. |
| **High** | Allows significant unauthorized access to sensitive data or functionality, or is a key enabler for a Critical finding, but requires an additional step or condition. |
| **Medium** | Weakens an intended security control (e.g., authorization, session handling) without by itself granting full data or system access. |
| **Low** | Discloses information that aids an attacker's reconnaissance or narrows their search space, without directly exposing sensitive data. |
| **Informational** | Worth recording and fixing as good practice, but presents no meaningful exploitable risk on its own. |

**Important:** These ratings describe severity **within the fictional lab environment used for this assessment only**. They are not a statement about any real system, and they should not be read, copied, or cited as an assessment of a production environment.

--- 

## 4. Findings Summary

| ID | Title | Affected Component | Severity |
-|-|-|-
| NB-01 | Administrative Interface Discoverable via Directory Enumeration | `/admin/` | Low |
| NB-02 | Sensitive Credentials Exposed in Public Configuration File | `/.env` | High |
| NB-03 | Weak Authentication Controls Enable Password Spraying | `/admin/index.php` | High |
| NB-04 | Inadequate Authorization Controls in Restricted Record View | `/admin/edit-marks.php` (default view) | Medium |
| NB-05 | SQL Injection in Administrative Search Functionality | `/admin/edit-marks.php?search=` | Critical |
| NB-06 | Local File Inclusion Through Unvalidated File Path Parameter | `/admin/edit-marks.php?id=` | Critical |

--- 

## 5. Detailed Findings

### NB-01 — Administrative Interface Discoverable via Directory Enumeration

| Subsection | Content |
|---|---|
| **Summary** | The administrative interface exists at a predictable path and is not linked from any page a normal visitor would reach, but is discoverable through routine directory enumeration. |
| **Severity + rationale** | **Low.** This finding by itself discloses only the *existence* of a hidden interface — it does not expose data or bypass any access control. It is rated Low rather than Informational because it materially narrows an attacker's search space and is a necessary first step toward every other finding in this report. |
| **Affected component** | `/admin/` and its child routes. |
| **Description** | The application relies on the absence of a navigation link as its only protection for the administrative area. The server does not distinguish between "this route does not exist" and "this route exists but is unlinked" — both a genuinely missing page and the admin login page return normal, successful responses for requests that correctly guess the path, while a non-existent path returns the application's branded not-found page. This gives an attacker a reliable signal for distinguishing real routes from guesses. |
| **Evidence** | A request for a common staff/admin path returns a normal login page rather than a not-found response, while a request for a genuinely non-existent path returns the application's branded error page: <br><br>`curl -i http://<vm-IP>:<port>/admin/` → HTTP 200, returns a login form<br>`curl -i http://<vm-IP>:<port>/this-path-does-not-exist/` → HTTP 404, returns the branded not-found page<br><br>The difference in response confirms the existence of the hidden route without requiring any credentials. |
| **Root cause** | Access control is implemented as "don't link to it" (security through obscurity) rather than as a server-side check that distinguishes authorized from unauthorized requests. |
| **Impact** | On the fictional lab dataset, this finding alone discloses no data — its impact is purely informational, in that it identifies the entry point for every other finding in this report. In a real deployment, an equivalent weakness commonly manifests as a staff or admin portal that is "hidden" from the public site but fully reachable by URL, and is routinely found by automated crawlers and enumeration tools within minutes of a target going live. |
| **Remediation summary** | Do not rely on link visibility as an access control. Every administrative route should perform a server-side authentication (and, once authenticated, authorization) check before returning any content, so that an unauthenticated request receives a `401`/`403` or a redirect to login regardless of whether the route is linked anywhere. |
| **Verification** | Confirm that an unauthenticated request to any administrative route returns `401`/`403` (or a redirect to a login page with no page content disclosed), and that this behavior is identical whether or not the exact path is guessed correctly. |  
</br>  

### NB-02 — Sensitive Credentials Exposed in Public Configuration File

| Subsection | Content |
|---|---|
| **Summary** | A configuration file containing administrator credential pairs is served directly by the web server to unauthenticated requests. |
| **Severity + rationale** | **High.** This finding directly discloses credential material to any unauthenticated visitor who finds the file, and that material is immediately usable against the authentication finding described in NB-03. It is not rated Critical in isolation because disclosure of credentials still requires a subsequent authentication step to produce impact. |
| **Affected component** | A dotfile-style configuration artifact served from the web root (`/.env`). |
| **Description** | The web server is configured to serve all files under the web root by default, including files that begin with a dot. One such file in the web root contains environment-style configuration data, including what appear to be administrator username/password pairs. No authentication, content-type restriction, or web-server rule prevents this file from being requested and returned like any other static resource. |
| **Evidence** | `curl -i http://<vm-IP>:<port>/.env` returns HTTP `200` with a `text/plain` body containing configuration key/value pairs, rather than the expected `403`/`404`. The response confirms the file is both present and readable over HTTP; its specific contents are not reproduced in this report. |
| **Root cause** | The web server has no rule blocking dotfiles or other non-public configuration artifacts from being served, and no sensitive configuration data is kept outside the web root. |
| **Impact** | On the fictional dataset, this exposes synthetic staff credential pairs usable to authenticate to the administrative portal. In a real deployment, this class of weakness routinely exposes database connection strings, API keys, and service credentials, and is one of the most common root causes of full environment compromise in incident write-ups, because the exposed secrets are frequently valid for far more than the web application itself. |
| **Remediation summary** | Move all configuration and secret material outside the web root entirely, so it is not reachable by any URL the web server can route to. As defense in depth, explicitly deny web-server access to dotfiles and other known-sensitive filename patterns. |
| **Verification** | Confirm that requests for the configuration file path, and for common configuration-file naming patterns generally, return `403`/`404` with no file content, and confirm (by code or configuration review) that no secret material exists anywhere under the web-server-accessible directory. |  
</br>  

### NB-03 — Weak Authentication Controls Enable Password Spraying

| Subsection | Content |
|---|---|
| **Summary** | The administrative login accepts an unlimited number of attempts with no rate limiting, lockout, or challenge mechanism, allowing credential pairs to be tested exhaustively. |
| **Severity + rationale** | **High.** Combined with NB-02, this finding is the direct path to an authenticated administrative session, which is the precondition for every finding that follows. It is not Critical in isolation because it does not by itself expose data — it only removes a control that would otherwise slow or stop credential testing. |
| **Affected component** | `/admin/index.php` (administrative login endpoint). |
| **Description** | The login endpoint returns a response that differs only in a short failure message when credentials are wrong, and accepts repeated submissions from the same client with no increasing delay, temporary lockout, CAPTCHA, or other throttling after repeated failures. This means a list of candidate credential pairs — such as the pairs disclosed in NB-02 — can be submitted in full without any control intervening. |
| **Evidence** | Repeated `POST` requests to the login endpoint with varying credential pairs each return promptly with the same generic failure response, with no change in response time, no temporary block, and no challenge introduced after multiple consecutive failures from the same source. No credential values or working request bodies are reproduced here. |
| **Root cause** | The authentication endpoint implements credential verification only, with no attempt-tracking, throttling, or lockout logic attached to it. |
| **Impact** | On the fictional dataset, this allows the credential list from NB-02 to be tested to completion, yielding a working administrative session. In a real deployment, the equivalent weakness — often called password spraying when attempted broadly across many accounts — is a leading initial-access technique precisely because it requires no vulnerability beyond the absence of a rate limit. |
| **Remediation summary** | Add attempt throttling and account lockout (or an increasing delay) after a small number of consecutive failures per account and per source, and ensure failure responses do not leak whether the username or the password was the incorrect part. |
| **Verification** | Confirm that after a small, defined number of consecutive failed attempts, further attempts are rejected or delayed regardless of whether the submitted credentials are correct, and that this throttling is enforced server-side (not just in client-side JavaScript). |  
</br>  

### NB-04 — Inadequate Authorization Controls in Restricted Record View

| Subsection | Content |
|---|---|
| **Summary** | The default administrative record view shows only a limited subset of student records, but this restriction is a display-layer filter rather than an enforced authorization boundary. |
| **Severity + rationale** | **Medium.** This finding does not by itself expose additional data through the default view — it is rated Medium because it creates a false impression of scoping that, once bypassed via other parameters on the same page, fails silently rather than being blocked. |
| **Affected component** | `/admin/edit-marks.php` (default, unfiltered view). |
| **Description** | When an authenticated staff user loads the record view with no additional parameters, only a small, apparently department-scoped set of records is returned. This gives the impression that the backend is enforcing a departmental or role-based boundary. In fact, the limitation is applied only to the specific query used for the default view; other inputs accepted by the same endpoint are not subject to the same scoping and can return records well outside the intended subset (see NB-05). |
| **Evidence** | The default, parameter-free request to the record view returns a small, consistent set of records. Supplying additional parameters recognized by the same endpoint (documented separately under NB-05) returns records outside that set, confirming that the restriction observed in the default view is not enforced as a general authorization rule for the endpoint. |
| **Root cause** | The intended scoping rule ("a staff user should only see their own department's records") is implemented once, for one query path, rather than as a rule enforced centrally for every way the endpoint can be asked for data. |
| **Impact** | On the fictional dataset, this means the apparent default-view restriction provides no real protection once any other input on the same endpoint is used. In a real deployment, this pattern — a UI or single query path that appears to scope data correctly while other code paths on the same feature do not re-apply the same check — is a common source of data exposure in systems that otherwise appear to have working access controls. |
| **Remediation summary** | Enforce the authorization scope (e.g., department or role) as a condition applied to every query the endpoint can execute, at the data-access layer, rather than relying on a single query being written correctly. |
| **Verification** | Confirm that every parameter combination accepted by the endpoint, not just the default view, is scoped to the authenticated user's authorized records, and that this is enforced even when the request is crafted to request records outside that scope. |  
</br>  

### NB-05 — SQL Injection in Administrative Search Functionality

| Subsection | Content |
|---|---|
| **Summary** | The administrative record search parameter is incorporated into a database query without parameterization, allowing an authenticated attacker to alter query logic and retrieve data outside the intended scope. |
| **Severity + rationale** | **Critical.** This finding allows full retrieval of the application's database contents from a single input field, requiring only an authenticated session (itself reachable via NB-02/NB-03) and no further privilege. |
| **Affected component** | `/admin/edit-marks.php?search=` |
| **Description** | The search parameter on the record-search feature is concatenated directly into a SQL query string rather than being passed as a bound parameter. Because the query's structure can be altered by the input itself, an attacker can change what the query returns, extend it to pull additional columns or tables, and ultimately extract records never intended to be reachable through this feature — including the data underlying the restricted view described in NB-04. |
| **Evidence** | Submitting ordinary text to the search field returns normally formed result rows. Submitting an input that alters the query's logical structure (without altering any stored data) changes the shape and count of the returned result set in a way a text search alone could not produce, confirming that the input reaches the query unsanitized. For reproducibility, see Appendix A for the generic test pattern used; no working injection string is reproduced in the body of this report. |
| **Root cause** | User-supplied input is concatenated directly into a SQL statement rather than passed through a parameterized query or prepared statement. |
| **Impact** | On the fictional dataset, this allows an authenticated attacker to retrieve the full contents of the student and staff tables, regardless of the department scoping intended by NB-04. In a real deployment, SQL injection of this kind routinely leads to full database exfiltration, and — depending on database permissions — can extend to data modification, deletion, or further compromise of the hosting environment. It is consistently ranked among the most severe classes of web application vulnerability (OWASP Top 10, A03: Injection). |
| **Remediation summary** | Rewrite every query on this code path to use parameterized queries or prepared statements, with no exceptions for any branch of the search logic, and re-apply the authorization scoping from NB-04 at the query level so that even a corrected query cannot return out-of-scope rows. |
| **Verification** | Confirm that the same structural-alteration test described above no longer changes the shape of the result set, and that the search feature cannot return rows outside the authenticated user's authorized scope under any input. |  
</br>  

### NB-06 — Local File Inclusion Through Unvalidated File Path Parameter

| Subsection | Content |
|---|---|
| **Summary** | A second parameter on the same endpoint accepts either a record identifier or an absolute filesystem path with no validation, allowing an authenticated attacker to read arbitrary files accessible to the web server process. |
| **Severity + rationale** | **Critical.** This finding allows an authenticated attacker to read files outside the application and outside the database entirely, including files the application was never intended to expose, with no further privilege required. |
| **Affected component** | `/admin/edit-marks.php?id=` |
| **Description** | The `id` parameter on the record-editing feature is intended to identify a single student record. The application's handling of this parameter distinguishes a record identifier from a filesystem path only by checking whether the value begins with a path separator — there is no allowlist of valid identifiers, no restriction on traversal sequences, and no check that the resolved value stays within an intended directory. When the value is recognized as a path, its contents are read and returned using the same privileges as the web server process. |
| **Evidence** | Supplying an ordinary identifier value returns the expected single-record response. Supplying a value recognized as a filesystem path by the application's own logic returns file content instead of record data, confirming that the parameter is used directly in a file-read operation without validation. The specific file paths read during testing are not reproduced in this report. |
| **Root cause** | User-controlled input is used to construct a filesystem path and passed to a file-read operation with no allowlist, no canonicalization/traversal check, and no restriction to an intended directory. |
| **Impact** | On the fictional dataset, this allows an authenticated attacker to read any file accessible to the web server account, including application source and any file left reachable outside the database. In a real deployment, local file inclusion of this kind is routinely used to read source code (disclosing further vulnerabilities or secrets), configuration and credential files, and — depending on server configuration — can sometimes be escalated to remote code execution. It is a severe, system-level consequence of a single unvalidated input. |
| **Remediation summary** | Never use user-supplied input to construct a filesystem path directly. Replace the identifier/path dual behavior with a strict allowlist of valid record identifiers (or an indirect lookup table), reject any input that does not match, and run the web server process with the minimum filesystem privileges it needs. |
| **Verification** | Confirm that the parameter no longer accepts any value capable of resolving to a filesystem path outside an explicit, intended set of values, and that the web server process cannot read files outside its minimum required working set even if a validation check were bypassed. |

---

## 6. Findings Considered and Not Reported

The following observations were investigated during the assessment and intentionally
excluded from the findings above, with the reasoning for each decision recorded for
the reviewer.

1. **Verbose default error pages.** The application's default (non-branded) error
   responses in a small number of edge cases included a framework-level stack
   trace fragment rather than the application's own error page. This was not
   raised as a standalone finding because it was only reproducible by deliberately
   malforming a request in a way that provides no additional access beyond what
   NB-05 already demonstrates, and the leaked detail did not materially aid
   exploitation beyond what was already observable from NB-05's evidence. It is,
   however, worth fixing as part of general hardening (ensure all error paths
   render the application's branded error page, never a framework default).

2. **Session cookie lacks the `Secure` attribute.** The session cookie issued at
   login is not marked `Secure`. This was not raised as a standalone finding
   because the lab environment is served exclusively over plain HTTP by design —
   there is no TLS channel for the attribute to protect in this environment, so
   the control would currently have no effect either way. It should be revisited
   the moment the application is served over HTTPS in any environment, at which
   point it becomes a real finding.

3. **Username enumeration via response timing.** A difference in response time was
   observed between submitting a valid username with a wrong password and
   submitting a username that does not exist at all. This was not raised as a
   standalone finding because the difference is small, inconsistent across
   repeated tests, and strictly less useful to an attacker than the credential
   pairs already obtainable via NB-02 — meaning fixing NB-02 and NB-03 removes
   the practical value of this behavior regardless of whether it is independently
   fixed. It is noted here so a future review does not need to re-discover it.

4. **No Content Security Policy header.** The application does not set a
   Content-Security-Policy header. This was investigated for stored or reflected
   cross-site scripting opportunities; none were found during this assessment,
   so the missing header currently has no identified vector to mitigate. It is
   recorded as a defense-in-depth gap rather than a finding tied to a
   demonstrated vulnerability.

---

## 7. Residual Risk and Limitations

- **The lab is intended to remain vulnerable.** This application is deliberately
  built to demonstrate the findings above for training purposes; the findings in
  this report describe what must change for a **production-equivalent** build, not
  a request to alter the lab itself. "Fixing" this application in the sense a real
  engineering team would mean not shipping an application with these
  characteristics at all — the correct real-world remediation is architectural
  (parameterized queries, proper authorization, secrets management, rate limiting,
  and least-privilege file access) applied from the outset, not a patch applied to
  this specific codebase.
- **This assessment covers the application layer only.** No conclusions are drawn
  about host-level hardening, network segmentation, or infrastructure security
  beyond what was necessary to observe application behavior.
- **No automated scanning was performed.** Findings reflect what a manual review
  within the engagement window identified; the absence of additional findings
  should not be read as a guarantee that none exist.
- **All findings are scoped to the fictional dataset in the lab.** Severity
  ratings and impact statements describe what is true for the data and
  environment assessed, not any other system.

---

## 8. Appendix

### Appendix A — Reproduction Commands

All commands below are scoped to the assessed lab instance only
(`http://<vm-IP>:<port>` — the specific host and port are environment-specific and
are deliberately not fixed in this report) and uses only generic, non-weaponized
inputs sufficient to demonstrate behavior.

```text
# NB-01 — confirm a hidden route resolves differently from a genuine 404
curl -i http://<vm-IP>:<port>/admin/
curl -i http://<vm-IP>:<port>/this-path-does-not-exist/

# NB-02 — confirm the configuration artifact is served over HTTP
curl -i http://<vm-IP>:<port>/.env

# NB-03 — confirm no throttling after repeated failed login attempts
# (repeat a POST to the login endpoint N times with varying, non-sensitive
#  placeholder credentials and confirm response time/behavior is unchanged)
curl -i -X POST http://<vm-IP>:<port>/admin/index.php --data "username=<candidate>&password=<candidate>"

# NB-04 — compare the default (scoped) view against the same endpoint with
# additional parameters, confirming the scope is not consistently applied
curl -i -b "<session-cookie>" http://<vm-IP>:<port>/admin/edit-marks.php
curl -i -b "<session-cookie>" "http://<vm-IP>:<port>/admin/edit-marks.php?search=<test-pattern>"

# NB-05 — confirm search input alters query structure (generic structural
# test only; no working injection payload is included here)
curl -i -b "<session-cookie>" "http://<vm-IP>:<port>/admin/edit-marks.php?search=<structural-test-pattern>"

# NB-06 — confirm the id parameter is treated as a filesystem path when the
# value takes that form (generic test only; specific paths withheld)
curl -i -b "<session-cookie>" "http://<vm-IP>:<port>/admin/edit-marks.php?id=<record-id>"
curl -i -b "<session-cookie>" "http://<vm-IP>:<port>/admin/edit-marks.php?id=<absolute-path>"
```

### Appendix B — Glossary

| Term | Plain-language meaning |
|---|---|
| **Directory enumeration** | Systematically guessing or checking web addresses to find pages that exist but are not linked from anywhere on the visible site. |
| **Password spraying** | Trying a list of known or guessed passwords against one or more accounts, usually slowly enough to avoid detection, instead of guessing many passwords against a single account. |
| **SQL injection** | A flaw where user input is placed directly into a database command, letting an attacker change what the command does instead of just supplying a value for it. |
| **Local file inclusion (LFI)** | A flaw where an application can be made to read a file the attacker chooses, instead of only the files it was designed to read. |
| **Authorization vs. authentication** | Authentication confirms *who* someone is (logging in); authorization confirms *what* that person is allowed to do or see once logged in. A system can authenticate correctly while still failing to authorize correctly. |
| **Parameterized query / prepared statement** | A way of sending a database command and its data separately, so user-supplied data can never change the structure of the command itself. |
| **Rate limiting / account lockout** | Controls that slow down or temporarily block repeated attempts (such as login attempts), making automated guessing impractical. |
| **Severity rating** | A structured judgment of how serious a finding is, based on how easily it can be exploited and how much damage it could cause if it were. |

---
