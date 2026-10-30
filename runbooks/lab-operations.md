# Lab Operations Runbook — Northernbridge College Portal

**Audience:** Whoever runs or maintains this lab next  
**Purpose:** Build, verify, reset, update, and hand over the lab with no archaeology  
**Last updated:** Phase 5 (Final)

---

## 1. What this is

The Northernbridge College Portal is an isolated, single-VM training lab with fictional data. It is **intentionally vulnerable** for teaching purposes.

There are **two separate build variants**:

| Variant | Location | Provisioner | Intended use |
| :-- | :-- | :-- | :-- |
| **Vulnerable (CTF target)** | `www/` (synced in dev mode) / cloned via `infra/provision.sh` | `infra/provision.sh` (default via `Vagrantfile`) | **For students.** Must remain exploitable. |
| **Hardened (verification artifact)** | `hardened/www/` | `hardened/infra/hardened_provision.sh` | **For verification only.** Never hand to students. Proves all findings are fixable. | 

> **Rule:** The two builds are separate artifacts. There is no runtime "vulnerable mode" switch. 

---


## 2. Prerequisites

### Host requirements
- Windows, macOS, or Linux host with virtualization enabled (Intel VT-x/AMD-V)
- At least 2GB RAM free (4GB recommended)
- At least 10GB free disk space
- Network access to download Ubuntu box on first run

### Required tools
| Tool | Notes |
| :-- | :-- |
| [Vagrant 2.4.9](https://www.vagrantup.com/) | Used to provision the VM. |
| [VirtualBox 7.2.4](https://www.virtualbox.org/) | Hypervisor used by the provided `Vagrantfile`. Other providers may work but are untested. |
| Git (optional) | Only needed if using non-dev mode cloning. Dev mode uses synced folders. |

### Student prerequisites
- A browser or `curl` 
- Basic web fundamentals (routes, forms, HTTP) and scanning tool.
- No special tools are required to complete the intended path. 


---


## 3. Build the lab (vulnerable CTF target)

### Option A: Clean clone provisioning (recommended for this repo) 
This repo is set up to clone application source directly from configured repo/branch using`infra/provision.sh` while spinning up the VM. he configured repo/branch.
```bash
# From the repo root
vagrant up
```

### Option B: Development mode 
If `DEV_MODE` is enabled, `infra/provision.sh` will sync application source from `./www` into the VM.

```bash
# From the repo root
$env:DEV_MODE="1"
vagrant up
```

### Expected output
- Apache installed and configured for `northernbridge.local`
- Decoy `/.env` placed in the web root
- SQLite database seeded from `seed.sql`
- Flag written to `/opt/northernbridge/flag.txt` (outside the database)
- Access banner showing NAT and/or Bridged IPs and HTTP status

### Verify it's up
```bash
# From host
curl -i http://<VM_IP>/
```

A healthy vulnerable build should return HTTP 200 with the Northernbridge College Portal homepage. 


---


## 4. Verify the lab

Run these checks after a fresh build to confirm the lab is in a known-good, exploitable state (as intended for students).

| Check | Command (from host) | Expected |
| :-- | :-- | :-- |
| **Homepage loads** | `curl -i http://<VM_IP>/` | HTTP 200, portal homepage renders |
| **`.env` is exposed (intentional)** | `curl -i http://<VM_IP>/.env` | HTTP 200, `text/plain`, contains decoy credential pairs (no real creds) |
| **Admin route discoverable** | `curl -i http://<VM_IP>/admin/` | HTTP 200, admin login form (not a branded 404). This is NB-01. |
| **Genuine 404 differs** | `curl -i http://<VM_IP>/this-path-does-not-exist/` | HTTP 404, branded `404.html` (different from `/admin/`) |
| **DB present** | SSH in: `ls -la /var/lib/northernbridge/college.db` | File exists, owned by `www-data` |
| **Flag exists outside DB** | SSH in: `ls -la /opt/northernbridge/flag.txt` | Exists, `root:www-data`, mode `640` |

> See [`docs/Findings-Report.md`](../docs/Findings-Report.md) for the full reproduction patterns. Do **not** copy weaponized payloads into public student materials. 


---


## 5. Reset between students and between cohorts

The lab must be reset to a clean, exploitable state between uses.

### Quick reset (recommended)
```bash
# From repo root (host)
vagrant destroy -f
vagrant up
```

This reprovisions from scratch. The decoy `.env`, database, and flag will be regenerated as per `infra/provision.sh`.

### Confirm reset
1. Re-run the checks from Section 4
2. Confirm `/admin/` is still discoverable
3. Confirm `/.env` is still retrievable
4. Confirm the database is freshly seeded


---


## 6. Build the hardened variant (verification only)

The hardened build is **not for students**. Only use it to verify remediations.

### Provision
```bash
# From repo root (host)
vagrant up hardened
```

The `hardened` machine is defined with `autostart: false`, so it will not start with a plain `vagrant up`.

### Verify hardening
| Check | Command | Expected |
| :-- | :-- | :-- |
| **Site loads** | `curl -i http://<HARDENED_VM_IP>/` | HTTP 200, student routes still function |
| **Dotfiles blocked** | `curl -i http://<HARDENED_VM_IP>/.env` | `404` or `403`, **never** `200` |
| **Admin unauthenticated** | `curl -i http://<HARDENED_VM_IP>/admin/` | Redirect to login or `403`, **never** admin dashboard content |
| **Search parameterized** | Authenticated test with structural input | No schema leakage, result shape unchanged by input structure |
| **Authz enforced** | Authenticated clerk requests out-of-scope student via `?id=` | "Student not found" / no rows returned (not exposed) |
| **LFI closed** | `curl -b "<session>" "http://<HARDENED_VM_IP>/admin/edit-marks.php?id=/etc/hostname"` | Normal response, **no** file contents |

See [`docs/Remediation-Guide.md`](../docs/Remediation-Guide.md) for full verification details.

> **WARNING:** Never deploy the hardened build to students. Never add a runtime switch to convert the vulnerable build to hardened mode.


---


## 7. Where things live

| Item | Path (in repo / on VM) | Notes |
| :-- | :-- | :-- |
| **Vulnerable app** | `www/` | Synced to `/var/www/html` in dev mode. |
| **Hardened app** | `hardened/www/` | Synced to `/var/www/html` for the hardened VM. |
| **Vulnerable provisioner** | `infra/provision.sh` | Default CTF provisioning. |
| **Hardened provisioner** | `hardened/infra/hardened_provision.sh` | Verification provisioning only. |
| **IP/access reporter** | `infra/report-access.sh` | Runs on every boot (`run: "always"`) to show current IPs. |
| **Seed data** | `seed.sql`, `hardened/hardened_seed.sql` | Database schema + fictional data. |
| **Decoy credentials** | `/.env` in web root (vulnerable only) | **Intentional.** Never created in hardened build. |
| **Flag (final)** | `/opt/northernbridge/flag.txt` (vulnerable only) | Outside the database. Not present in hardened build. |
| **DB** | `/var/lib/northernbridge/college.db` | Owned by `www-data`. |
| **Vagrant config** | `Vagrantfile` | Defines `vulnerable` (primary) and `hardened` (autostart: false). |
| **Docs** | `docs/` | Findings, remediation, learning objectives, retrospective, sign-off, etc. |
| **Runbooks** | `runbooks/` | This document. |


---


## 8. Logs and diagnostics

### Log locations (on VM)
| Log | Purpose |
| :-- | :-- |
| `/var/log/apache2/northernbridge_access.log` | HTTP requests |
| `/var/log/apache2/northernbridge_error.log` | Apache/PHP errors |
| `/var/log/syslog` | System events (including provisioning) |

### First three commands to run on failure
```bash
# 1) Check Apache status
sudo systemctl status apache2

# 2) Check recent Apache errors
sudo tail -n 30 /var/log/apache2/northernbridge_error.log

# 3) Check if site responds locally
curl -i http://127.0.0.1/
```

### Common issues
| Symptom | Fix |
| :-- | :-- |
| VM up but no IP shown / can't reach from host | Check bridged adapter. The provisioning includes a netplan override + polling for bridged DHCP. Try `vagrant reload` to re-run the `always` provisioner. |
| Permission errors on DB/app | Ensure `www-data` owns DB dir/files. Check `chown -R www-data:www-data /var/lib/northernbridge` and `/var/www/html` as appropriate for dev/prod mode. |
| Provision fails mid-way | Check the last lines of syslog. Common causes: package install timeout, git clone issues, or order-of-operations. For hardened, ensure schema exists before admin seeding. |
| Can't reach via bridged IP | Ensure host firewall isn't blocking. Use NAT IP as fallback. |


---


## 9. Updating the lab

### Safe changes
- Update student/instructor hints (in `Scenarios/` or guides) 
- Tweak UI copy in `www/` (dev mode)
- Update documentation

### Changes that must be updated together
If you change any of the following, verify they remain consistent:

| Change | Must update |
| :-- | :-- |
| **Routes/filenames** | `docs/learning-objectives.md`, `docs/CTF Design_&_Challenge-Flow.md`, student/instructor guides |
| **Seed data (`seed.sql`)** | Be careful not to accidentally fix the intentional flaws. Only change fictional data if explicitly approved by instructor. |
| **Admin credentials/`.env` pairs (vulnerable)** | Keep them fictional. Never introduce real creds. The vulnerable build's decoy is intentional. |
| **Flag location/name** | `infra/provision.sh`, guides, and ensure it stays outside the database |
| **Provisioning paths** | `Vagrantfile`, both provisioners, and this runbook |

### Rules
- **Never** commit flag values or valid credentials
- **Never** harden the vulnerable build
- **Never** add a runtime toggle between vulnerable/hardened
- Keep changes isolated to the intended scope


---


## 10. Handing over

### What to tell the next person
- This is an **isolated, authorized training lab** with fictional data only
- **Default build is vulnerable** — that is intentional
- **Hardened build is verification only** — never for students
- Use `vagrant destroy -f && vagrant up` to reset between cohorts
- Testing of both builds is required for full sign-off (see [`docs/final-signoff.md`](../docs/final-signoff.md))
- Refer to [`docs/retrospective.md`](../docs/retrospective.md) for lessons learned and next-cohort improvements

### What must never be committed
- Actual flag values
- Real credentials or personal data
- Working attack payloads intended for real systems
- Modifications that remove intentional flaws from the vulnerable build
- Runtime switches that enable/disable hardening
