# Team Retrospective — Northernbridge College Portal Lab

**Project:** Northernbridge College Portal CTF Lab  
**Phases covered:** 1–5  
**Audience:** Project team, instructor, and whoever picks up this lab next  
**Purpose:** Capture lessons learned while building/running the lab and concrete changes for the next cohort

---  
</br>  

## 1. What the team learned while building the lab

Building this lab was intentionally different from building a "secure by default" application. The tension was always: *make it exploitable enough to teach the lesson, but never make it look like an example of good practice*.

| Phase | Lesson learned | Notes |
| :-- | :-- | :-- |
| **Phase 1 – Setup & Architecture** | A lab needs strict scope. | Keeping the lab isolated to a single VM, host-only/bridged as provisioned, with fictional data prevented scope creep and kept the exercise safe. |
| **Phase 2 – Portal Build** | "Realistic enough" is harder than it looks. | Small details (routes, roles, UI copy) go a long way to make the story believable without adding unnecessary attack surface. |
| **Phase 3 – Vulnerabilities & Exploitation** | Hiding is not protecting. | Implementing the "hidden" admin route made it obvious that removing a link is purely cosmetic. It must be enforced server-side. |
| **Phase 3 – Secrets** | A single exposed file is high impact. | Writing a believable decoy `.env` drove home how much damage credential exposure causes when paired with weak authentication. |
| **Phase 3 – Injection/LFI** | Easy to write by accident. | Concatenating user input into SQL and treating an `id` parameter as both a record key and a filesystem path were both trivial mistakes to introduce. Fixing them correctly (prepared statements + strict allowlists) is not. |
| **Phase 4 – Teaching Artifacts** | Teaching vs. documenting are different audiences. | The student/instructor guides explain the *journey*. The findings/remediation must explain the *flaw, root cause, impact and real fix*. These must not be merged or duplicated. |
| **Phase 5 – Closing the loop** | Verification is the only thing that proves a fix. | "We changed the code" is not proof. The same test must fail on the vulnerable build and pass on the hardened build. Also, infrastructure details (Vagrant multi-machine, netplan/DHCP, provision order) matter more than expected. |

### Personal/Team learnings
- **Vagrant from scratch**: Vagrant was entirely new to us, so we had to go slowly to understand boxes, provisioning, networking, and multi-machine setups. It was challenging at first but very rewarding once it clicked.
- **Version control challenges**: We ran into Git conflicts, including merge conflicts, which taught us how to resolve them properly and be more careful with commits.
- **SQL Injection deep dive**: We learned what misconfigurations and how unsafe SQL queries actually could expose or manipulate database records. Understanding how parameterized queries/prepared statements prevent this was a key takeaway.
- **Credential & authentication risks**: We explored the risks of exposed credentials and why password spraying and weak credential management are serious security concerns. Seeing it play out in the lab made it very real.
- **Vulnerability remediation**: Confirming that the hardened build did not introduce new functional issues while fixing vulnerabilities reinforced the importance of regression testing.
- **Clarifying ambiguity**: Understanding requirements that were initially unclear taught us to ask questions, read carefully, and iterate until the fix matched the intent.
- **Technical communication**: We improved our technical communication by explaining vulnerabilities, root causes, impacts, and fixes in language that is clear for both technical and non-technical audiences.
- **Overall experience**: This was a great experience overall - We learned many new things, got hands-on with real security concepts, and built confidence in both offensive understanding and defensive remediation.

---
</br>  

## 2. What the lab teaches students

Refer to [`Scenarios/NCC_learning-Objectives.md`](https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/f1ad20a7621dbbff914a5aa53181d15f9af59c55/Scenarios/NCC_Learning-Objectives.md) for the full list. The core arc is:

**Discovery → Exposed Secrets → Authorization Boundary → Data Exposure**

A student who completes this lab should be able to say, in their own words:

> *"An unlinked page is not access control. A public config file can hand an attacker valid credentials. Authentication needs throttling. The default view can lie about scope. SQL must never be built by string concatenation. User input must never be used to directly read arbitrary files. And 'not visible' is never the same as 'not reachable'."*

The value is not memorizing payloads, but recognizing those boundary failures and knowing the correct server-side controls to apply.

---  
</br>  

## 3. What worked, what did not, what to change
### 3.1 What went well
Item | Evidence | Why it worked 
-|-|-
Single Vagrantfile Architecture | `Vagrantfile` | Spinning up both the vulnerable and hardened versions of the VM from a single Vagrantfile was highly efficient. It allowed us to seamlessly switch between the CTF target (`vagrant up`) and the verification artifact (`vagrant up hardened`).
Custom Hardened Seed Data | `hardened_seed.sql` | Giving the hardened version different seed data—specifically adding a dedicated admin for each department—made testing our authorization boundaries much more robust and realistic than reusing the vulnerable seed.
Automated Regression Testing | `regression-test.sh` | We successfully built a full automated test script. Having it programmatically test both unauthenticated routes (NB-01) and authenticated exploits (NB-04, 05, 06) using session cookies proved our fixes definitively. 
Decoupled Search vs. Edit Authorization | `fetch_authorized_student()` | We successfully nailed the complex authorization logic: imposing restriction on admins, so they can only search and edit student records within their own department, (whether they are NB or NC records).

## 3.2 What did not go well
Item | Concrete example | EffectAutomated 
-|-|-
Authenticated Testing Complexity | Writing the regression-test.sh logic for NB-04, NB-05, and NB-06. | Getting the Bash script and powershell script to properly authenticate via POST, save the session cookie to a file, and pass it into subsequent curl requests took several iterations to get right.
Vagrant networking gotchas | Bridged adapter needed netplan override + polling; IP report only ran once by default. | vagrant up looked "done" but the "access" banner could be stale or miss the bridged IP. Fixed with a run: "always" provisioner and a DHCP polling loop.
Provisioning order mistakes | Dotfile block regex/directive broken initially; id= had leftover LFI copies after partial edits. | Slowed down getting a clean hardened build initially. Required destroying and re-provisioning the VM after structural changes.

## 3.3 What was confusing
Area | Explanation | 
-|-
Vagrant Multi-Machine Commands | Because both the vulnerable and hardened builds now live inside the same Vagrantfile, it was initially confusing to ensure we were targeting the right machine. We had to repeatedly stress that `vagrant up` targets the vulnerable CTF by default, and `vagrant up hardened` must be explicitly typed for the verification build.
NB-03 vs NB-04 vs NB-05 | Easy to conflate authentication, UI scoping, and SQL injection. The findings report had to keep them as distinct findings with their own evidence, especially since we explicitly allowed cross-department searching but blocked cross-department editing.

## 3.4 Surprises
- **Verification forces discipline:** Writing the fully automated `regression-test.sh` script exposed how weak manual testing can be. It forced us to programmatically prove that the cross-department edit restriction actually held up against direct ID manipulation.

---  
</br>  

## 4. Changes for the next cohort
Prioritized list with owner and effort estimate. Treat as actionable, not wishful.

Priority | Change | Owner | Effort | Rationale
-|-|-|-|-
P0 | Make "reset between students" one command | Lab Maintainer | S (2-4 hours) | Add scripts/reset-lab.sh that re-runs the documented reset and runs a minimal sanity check (home loads, /admin behavior correct for vulnerable build).
P1 | Add a short "hidden vs protected" micro-exercise | Instructor | S (1-2 hours) | Explicitly quiz students on NB-01 before moving to NB-02 to solidify the mental model.
P1 | Tighten docs cross-references | Tech Writer/Dev | S (1-2 hours) | Ensure docs/learning-objectives.md is referenced from findings/remediation/retrospective (already done) and remove any accidental duplication.
P1 | Harden runbook with "first 3 commands on failure" | Lab Maintainer | S (1-2 hours) | Expand runbooks/lab-operations.md logs/diagnostics based on the Vagrant/networking issues we hit.
P1 | Regular sync meetings (Meet/Zoom) | Project Lead/Instructor | S (Ongoing) | From the team side, regular meetups through Meet or Zoom would greatly help maintain communication, clarify requirements earlier, and resolve blockers faster.
P1 | Provide more upfront examples for new tools | Instructor/Mentor | S (1-2 hours) | For tools like Vagrant that are new to some team members, a short walkthrough/demo at the start would help flatten the learning curve.
P2 | Add instructor-only "spoiler map" | Instructor | S (1-2 hours) | Keep exploitation paths in instructor guide only. Never move weaponized strings into student docs.
P2 | Consider seed checksum | Lab Maintainer | M (1 day) | Optional: verify seed.sql hash on provision to catch accidental edits that break the intended exercise. Only do this if it doesn't complicate resets.

*Effort: S = small, M = medium, L = large*

---  
</br>  

## 5. Honest limitations
Limitation | Explanation 
-|-
Doesn't teach host hardening | Focus is strictly application-layer. OS hardening, firewall configuration, patch management are out of scope by design.
Doesn't teach secure coding from scratch | Teaches how to spot and fix these specific failures. A separate secure coding course is needed to generalize.
Throttling is defense-in-depth | The NB-03 fix includes a lockout mechanism tracking attempts by IP and username, but this static threshold is vulnerable to IP rotation and distributed attacks. In a production environment, Multi-Factor Authentication (MFA) and behavioral heuristics are required.
LFI is constrained | We removed the dual behavior entirely. A more complex app might need a controlled download feature — that would require a strict allowlist + chroot-like constraints, not "block traversal".
Search vs. Edit Authorization | The lab specifically allows administrators to search out of their department but strictly blocks editing out-of-scope records. While this isolates the teaching points, a real production system with strict privacy requirements might also need to enforce hard scoping on the search results themselves.
Fictional only | All data/creds are synthetic. Students must not extrapolate to real systems.

---  
</br>  

## 6. Instructor feedback

Feedbacks will help future maintainers to resolve issues, improvise and maintain the repo.

Here are the step to send us your feedback:  
- **Step 01:** Go to GitHub Issues Tab  
- **Step 02:** Click `New Issue` button (top right-corner)  
- **Step 03:** Select `Instructor Feedback` Option  
