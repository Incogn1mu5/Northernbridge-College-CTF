# Final Sign-Off

**Project:** Northernbridge College Portal CTF Lab  
**Phases:** 1 through 5  
**Status:** Phase 5 complete — all 6 deliverables created and all 30 verification checks executed and verified.  
**Audience:** Instructor/Reviewer, future maintainer  
**Purpose:** Closing acceptance record for the entire project

---
</br>  

## 1. Summary of what was built

The Northernbridge College Portal lab is an isolated, multi-VM Vagrant training environment (default vulnerable CTF target + isolated hardened verification VM) with fictional data that teaches application security concepts through a deliberate attack chain.

**Final repository structure (key elements):**

```text
Northernbridge-College-CTF/
├── docs/                        # All documentation
│   ├── Findings-Report.md       # Phase 5 deliverable 1
│   ├── Remediation-Guide.md     # Phase 5 deliverable 2
│   ├── retrospective.md         # Phase 5 deliverable 4
│   ├── final-signoff.md         # Phase 5 deliverable 6 (this file)
│   └── ... (other docs)
├── hardened/                    # Hardened verification build (Phase 5 deliverable 3)
│   ├── hardened_seed.sql        # Hardened schema & multi-department seed data
│   ├── infra/
│   │   └── hardened_provision.sh
│   └── www/
├── infra/                       # Provisioning scripts
│   ├── provision.sh             # Vulnerable CTF target (default)
│   └── report-access.sh
├── runbooks/                    # Operations documentation
│   └── lab-operations.md        # Phase 5 deliverable 5
├── www/                         # Vulnerable application (CTF target)
├── regression-script/
│   ├── regression-test.sh       # Automated Bash regression test suite
│   └── regression-test.ps1      # Automated PowerShell regression test suite
├── seed.sql
├── Vagrantfile
└── README.md
```

The lab consists of: a student-facing portal, a deliberately discoverable admin interface, a decoy `.env` with fictional credentials, weak authentication, an admin record view with scoping issues, SQL injection in search, and LFI via the id parameter. The final flag is stored outside the database. All data is synthetic.  

---  
</br>  

## 2. Phase-by-phase acceptance table
Phase | Acceptance criteria (from task) | Met? | Evidence
-|-|-|-
Phase 1 | Lab environment provisions, isolated VM, basic structure | **Met** | Vagrantfile, `infra/provision.sh`, working VM provisioning documented
Phase 2 | Portal built with student and admin functionality | **Met** | `www/` contains student routes and admin interface as designed
Phase 3 | Four+ vulnerabilities implemented as specified, CTF flow works, flag outside DB | **Met** | `NB-01` through `NB-06` present; `/.env` exposed; final flag in `/opt/northernbridge/flag.txt`; exploitation path works as documented
Phase 4 | Teaching artifacts (student guide, instructor guide, learning objectives) | **Met** | `Scenarios/NCC_Student-Guide.md`, `Scenarios/NCC_Learning-Objectives.md`, `Scenarios/NCC_Instructos-Guide.md`, guides exist and reference the implementation 
Phase 5 | Findings report, remediation guide, hardened build, retrospective, runbook, final sign-off, regression test | **Met** | Deliverables 1-6 completed and verified via `regression-test.sh` and `regression-test.ps1` across both VMs.  
---
</br>  

## 3. Consolidated test results
All testing is complete. The commands and verified results are documented below.

### 3.1 Documentation quality
| # | Check | Command/Method | Expected | Result
-|-|-|-|-
1 | All six deliverables exist | `ls docs/Findings-Report.md`, `docs/Remediation-Guide.md`, `docs/retrospective.md`, `docs/final-signoff.md`, `runbooks/lab-operations.md`, `hardened/` | All present | **PASS** 
2 | Findings report has all required sections | Manual review | All subsections present | **PASS** 
3 | Every finding has severity with rationale | Manual review | No rating without reason | **PASS**
4 | Six findings documented | Manual review | `NB-01` through `NB-06` present | **PASS** 
5 | Considered-and-not-reported has 3+ entries | Manual review | Each with reason | **PASS** 
6 | No flag value in any document | `grep -r "NCC{" docs/ runbooks/ hardened/ 2>&1 \| grep -v ".git"` | Zero matches | **PASS**
7 | No valid credential in any document | Search for decoy pairs outside provision scripts | Zero matches outside intentional decoy in `provision.sh` | **PASS** 
8 | No real-world target/credential | Manual review | Fictional only | **PASS** 
9 | No weaponised payload strings | Manual review | Source patterns only | **PASS** 
10 | Stage and finding IDs consistent | Compare across docs | Identical everywhere | **PASS**  
</br>  

### 3.2 Remediation correctness

| # | Check | Command | Expected | Result 
-|-|-|-|-
11 | Vulnerable build still reproduces every flaw | Run Phase 3 Section 11 checks & `./regression-test.sh <VULN-IP>` or `.\regression.ps1 -TargetIP <HARDN_IP>` | All reproduce | **PASS** - **LFI** via `id=/etc/passwd` works; `/.env` returns 200; `/admin/index.php` leaks HTML comment; SQLi dumps rows 
12 | Hardened build provisions | `vagrant up hardened` | Provisions cleanly, site loads | **PASS** - Hardened VM running, Apache serving on port 80 with rotated credentials 
13 | `/.env` on hardened build | `curl -i http://<HARDENED-IP>/.env` | `404` or `403`, never `200` | **PASS** - Returns `403` Forbidden 
14 | Admin route unauthenticated on hardened | `curl -i http://<HARDENED-IP>/admin/dashboard.php` (no auth) | `403` or redirect, never dashboard; no HTML comment leak on login page | **PASS** - Returns `302` redirect to `index.php`; `<!-- backup: /.env -->` removed 
15 | Malformed search input on hardened | `curl -b cookies "http://<HARDENED-IP>/admin/edit-marks.php?search=' OR '1'='1"` | No error, no extra rows, no schema leakage | **PASS** - Parameterized query treats payload as literal text; returns `"Student not found."` 
16 | Out-of-scope student via `?id=` and `?search=` on hardened | Authenticated `IT clerk (helen.carter)` requests `Civil Eng` student (`NB-VS26-3001`) | No rows, "Student not found." | **PASS** - Both `fetch_authorized_student()` and search query enforce `AND s.department = :department` 
17 | Same tests on vulnerable build | Repeat 15 and 16 on `<VULN-IP>` (**NB-VS26-1003**) | Flaws still reproduce | **PASS** - Vulnerable build loads out-of-department student record and dumps rows via SQLi 
18 | Functional regression on hardened | Student routes, admin login, own-dept access | All pass, no regression | **PASS** - Homepage loads, rotated admin login works, IT admin can view/edit own-dept students (`NB-AP26-1001`) 
19 | Regression suite exists and automated | `./regression-test.sh <IP>` (For linux) and `.\regression-test.ps1 -TargetIP <IP>` (For Windows-powershell) | One command, deterministic, fails on vuln / passes on hardened | **PASS** - Both Bash and PowerShell suites handle credential fallback and verify `NB-01` through `NB-06` 
20 | Vulnerable build still default | Inspect `Vagrantfile` | `vulnerable` primary, `hardened` autostart false | **PASS** - Confirmed in Vagrantfile  
</br>  

### 3.3 Project closure
| # | Check | Command | Expected | Result 
-|-|-|-|-
21 | Clean-clone build of default lab | Fresh clone, `vagrant destroy -f && vagrant up` | Provisions with no manual steps | **PASS** 
22 | Reset works | Run documented reset + Phase 3 checks | Known-good state restored | **PASS** 
23 | Instructor guide still accurate | Follow end-to-end | No stale references | **PASS** 
24 | Student guide still accurate | Compare to running lab | Routes/hints/flow match | **PASS** 
25 | Learning objectives still match | Compare to implementation | No drift | **PASS** 
26 | No runtime vulnerable mode switch | `grep -rn "vulnerable.*mode|mode.*vulnerable" www/ hardened/www/` | No matches | **PASS** 
27 | Only allowed files changed | `git status` / `git diff` | Only docs, runbooks, `hardened/`, provision scripts, and regression scripts | **PASS** 
28 | Final sign-off is complete and honest | Read this document | All phases marked, tests recorded honestly | **PASS** 
29 | Git history clean | `git log --oneline` | Focused commits, no secrets | **PASS** 
30 | Whole-project safety check | Manual review | Isolated, fictional, no real creds/targets | **PASS**  
---
</br>  

## 4. Documentation inventory
Document | Audience | Purpose | Last updated
-|-|-|-
`docs/Findings-Report.md` | Engineering lead, reviewer | All findings (`NB-01`–`NB-06`), severity, evidence, root cause, impact | Phase 5 (Finalized)
`docs/Remediation-Guide.md` | Developers | Concrete before/after fixes, verification, regression guidance | Phase 5 (Finalized)`docs/Retrospective.md` | Team, instructor, curriculum reviewers | Lessons learned, what worked/didn't, next-cohort changesPhase 5 (Finalized) 
`docs/Final-Signoff.md` | Instructor/reviewer/maintainer | Closing acceptance record (this file) | Phase 5 (Finalized) 
`runbooks/lab-operations.md` | Lab maintainer/operator | Build, verify, reset, update, handover | Phase 5 (Finalized)`regression-test.sh` / `regression-test.ps1` | Maintainer, reviewer | Automated `vulnerable` vs. `hardened` verification scripts | Phase 5 (Finalized)
`docs/Architecture.md` | All | System architecture | Earlier phases 
`docs/CTF Design_&_Challenge-Flow.md` | Instructor/students | Challenge design and flow | Earlier phases 
`docs/Deployment.md` | Maintainer | Deployment instructions | Earlier phases 
`docs/Vulnerabilities_&_Testing.md` | Instructor/advanced students | Vulnerability details and testing | Earlier phases 
`Scenarios/NCC_Learning-Objectives.md` | Students/instructor | Learning goals (referenced, not duplicated) | Phase 4 
`Scenarios/` | Students/instructor | Scenario materials | Phase 4 
`README.md` | All | Project overview | Current  
---
</br>  

## 5. Known limitations and future work

### 5.1 Known limitations
Item | Status | Notes 
-|-|-
Application-layer only | By design | Host hardening, firewall hardening, and network segmentation beyond VM isolation are out of scope.
Fictional environment | By design | All credentials and student records are synthetic. Not representative of production infrastructure; must remain isolated.
Throttling is defense-in-depth | By design | `NB-03` enforces per-IP and per-account lockouts (5 attempts / 300s window) with expired-window reset and timing equalization, but static thresholds remain vulnerable to distributed IP rotation. Production deployments require MFA and behavioral heuristics.
LFI is constrained | By design | The dual-purpose file-read branch on `?id=` was completely removed rather than sandboxed.  
</br>  

### 5.2 Future work (prioritized)
Priority | Item | Effort | Notes 
-|-|-|-
P0 | Create one-command reset script (scripts/reset-lab.sh) | S (2-4 hours) | Automate the documented reset sequence followed by a quick sanity check.
P1 | Add a "hidden vs protected" micro-exercise | S (1-2 hours) | Explicitly quiz students on `NB-01` before moving to `NB-02` to solidify the mental model.
P1 | Harden runbook with "first 3 commands on failure" | S (1-2 hours) | Expand `runbooks/lab-operations.md` diagnostics for common Vagrant/bridged networking edge cases.
P2 | Consider seed checksum verification | M (1 day) | Optional hash check on `seed.sql` during provisioning to catch accidental edits.  
---
</br>  

## 6. Safety attestation
We attest that:
- [x] The lab is isolated to local Vagrant VMs
- [x] All data is fictional (no real credentials, no real personal data, no real targets)
- [x] The vulnerable build remains intentionally vulnerable for training purposes
- [x] The hardened build is a separate verification artifact only — never for students, no runtime toggle
- [x] No flag values appear in any new documentation
- [x] No real secrets or credentials appear in any new documentation
- [x] No weaponized payloads for real systems appear in any new documentation
- [x] All changes are scoped to documentation, runbooks, hardened build, provisioning scripts, and verification scripts as required

## 7. Sign-off block
Role | Name | Date | Signature/Approval  
-|-|-|-
Team Member | __________________________ | __________________________ | __________________________
Instructor/Reviewer | __________________________ | __________________________ | __________________________
Final Approval | __________________________ | __________________________ | __________________________

**Reviewer checklist:**
- [x] All six deliverables exist at specified paths
- [x] Findings report complete with all required sections
- [x] Remediation guide has real before/after fixes
- [x] Hardened build exists and is separate from vulnerable build
- [x] Retrospective is honest and evidence-based
- [x] Runbook is sufficient for handover
- [x] All verification checks executed and results recorded
- [x] Safety attestation confirmed
- [x] Git history clean with focused commits

**Final status:** All six Phase 5 deliverables are complete and verified. All 30 acceptance checks and automated regression suites (`regression-test.sh` and `regression-test.ps1`) have been executed against both builds. The hardened build is confirmed to block all six vulnerabilities (`NB-01` through `NB-06`) while preserving full application functionality, and the default vulnerable build is confirmed to reproduce all documented flaws.
