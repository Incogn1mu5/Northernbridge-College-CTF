# Deployment
Northernbridge College CTF runs inside a Vagrant-managed Ubuntu VM. The VM hosts the complete website and database, so player devices only need a web browser.

The lab has two deployment mode:
* Normal Mode (default)
* Development Mode 

> <h2>1. Normal Mode</h2>

In this mode, the Git repository is the source of the application code deployed into the VM. Changes made to the host's application files do not automatically update the deployed site.  

deploy lab in normal mode:
``` powershell
vagrant up
```

* One script, `infra/provision.sh`, builds the entire CTF: it installs packages, clones the portal application from GitHub into `/var/www/html`, configures Apache, seeds the SQLite database, and places the challenge artifacts (decoy `.env` file and the filesystem final `Flag 04`).
</br>

> <h2>2. Development  Mode</h2>

Development mode is intended to let you edit your website files on Windows while Apache serves them from the Ubuntu VM, without having to clone and copy the application code on every change.

* Vagrant **synced folders** (`/vagrant`, `./www` are only used in the `Vagrantfile`) when user explicitly deploy lab in dev_mode using command:
```powershell
$env:DEV_MODE="1"
vagrant up
```
* One script, `infra/provision.sh`, builds the entire CTF: it installs packages, syncs `PHP` application files from host `./www` into `/var/www/html`, configures Apache, seeds the SQLite database, and places the challenge artifacts (decoy `.env` file and the filesystem final `Flag 04`).  
</br>

## Requirements

The host machine needs:

* VirtualBox
* Vagrant
* Git
* A local network that the player devices can access
* Internet access on first `vagrant up` (APT packages and the portal git clone)

The player devices do not need Vagrant, VirtualBox or the project files.  
</br>

## Reproducibility contract

From a **clean clone** on any host:

```bash
git clone <repository-url>
cd Northernbridge-College-CTF-2.0
vagrant up
```

produces an identical working lab. A full reset is:

```bash
vagrant destroy -f
vagrant up
```

The portal application is never read from the host at runtime — it is cloned into `/var/www/html` inside the VM by `infra/provision.sh`.  
</br>  

## Provisioning (`infra/provision.sh`)

The script is fully declarative. The configuration variables live at the top of the file:

```bash
PORTAL_REPO="https://github.com/<username>/<Repo-name>.git"  # GitHub URL of the portal source
PORTAL_BRANCH="main"                                                       # branch / tag to deploy
PORTAL_SUBDIR="www"                                                        # app directory inside the repo
PORTAL_SEED="seed.sql"                                                     # seed file inside the repo
PORTAL_DIR="/var/www/html"                                                 # VM-local web root
```

Steps performed:

1. Updates packages and installs `apache2`, `php`, `libapache2-mod-php`, `php-sqlite3`, `sqlite3`, `git`, `curl`, `rsync`.
2. Clones (or pulls) `PORTAL_REPO` at `PORTAL_BRANCH` into `/opt/northernbridge-src`.
3. Installs the app from `PORTAL_SUBDIR` into `PORTAL_DIR` — the `database/` directory is excluded from the sync.
4. Enables Apache modules (`rewrite`, `php`), writes the `northernbridge` virtual host pointing at `PORTAL_DIR` with custom `ErrorDocument` directives (`404.html` / `500.html`), disables directory listing, blocks direct `*.db` serving, denies direct access to `PORTAL_DIR/includes`, and applies production PHP settings (display errors off, logging on).
   The app's `.htaccess` (deployed with the portal) maps `/profile` and `/marks` to their `.php` pages (so unauthenticated requests there redirect to login) and funnels unknown routes through the branded 404 page.

The same variables can be overridden from the host shell before `vagrant provision`, which is how a lab operator deploys a custom portal fork (for example a local git-over-HTTP mirror) without editing the script:

```powershell
$env:PORTAL_REPO = "http://10.0.2.2:9418/mirror"
vagrant provision
```
5. Places the decoy credential file (`PORTAL_DIR/.env`) used by the password-spray stage.
6. Places the final `Flag 04` on the filesystem at `/opt/northernbridge/flag.txt` (outside the database); the legacy `flag-final.txt` path is removed.
7. **Idempotently** initializes the SQLite database from `PORTAL_SEED`. The seed is re-applied on every provision using `CREATE IF NOT EXISTS` / `INSERT OR IGNORE` (plus a small migration block), so existing player rows are never overwritten.
8. Sets permissions (`www-data`), restarts Apache and verifies the site answers HTTP 200 on `127.0.0.1:80`.  
</br>

### Idempotency

`vagrant provision` may be run repeatedly:

* The git checkout is updated in place (`fetch` + `checkout -B`).
* The web files are re-synced with `rsync` (database directory excluded).
* The decoy `.env` is always rewritten from the script (it is fictional data, not player data).
* The flag file is only written if missing, so a lab keeps its unique flag across reprovisions.
* The database seed is re-applied with `INSERT OR IGNORE` semantics, so existing rows are untouched.

### Addresses

The VM listens on two interfaces:

| Interface | Purpose | Access |
|---|---|---|
| NAT IP (inter-lab communication)| Both Testing and Target machine inside VirtualBox| `http://vm-NAT-IP/` |
| Bridged LAN IP | Player devices on the same network | `http://vm-Bridged-IP/` |
</br>

## Apache

Apache listens on port `80` inside the VM. The project uses the `northernbridge` Apache virtual host and serves the application from:

```text
/var/www/html
```

The student portal and admin portal are hosted by the same Apache instance.  
</br>

## Player Access

Once the VM is running, test the website from the host first:

```text
http://vm-NAT-IP/
OR
http://vm-Bridged-IP>/
```

Then test the same address from another device connected to the same network.

If a second device cannot connect, check:

* The VM received a LAN IP address.
* The host and player device are on the same network.
* The network does not have client/AP isolation enabled.
* Apache is running.
* Port `80` is not being blocked by the host or VM firewall.

The `northernbridge.local` Apache `ServerName` does not automatically create DNS for player devices, so using the VM's IP address is the simplest option for the CTF.  
</br>

## Challenge Artifacts

Deployed by the provisioning script, never committed to the repository:

| Artifact | Location | Purpose |
|---|---|---|
| SQLite database | `/var/lib/northernbridge/college.db` | application data, built from `seed.sql` |
| Decoy credential file | `/var/www/html/.env` | candidate admin passwords for the spray stage |
| Final `Flag 04` | `/opt/northernbridge/flag.txt` | filesystem flag — **not** in the database |
</br>

## Resetting the Lab

`seed.sql` is the source of truth for the initial database state, and the provisioning script regenerates everything.

For a fresh environment, destroy and recreate the VM:

```bash
vagrant destroy -f
vagrant up
```

Re-running `vagrant provision` on a live VM does **not** wipe the database (seeding is guarded), but `vagrant destroy -f` removes the whole VM so it always returns the lab to its seeded state.

Do not reset the database while players are using the CTF, as this can reset their progress and records.  
</br>  

## Reloading the lab

You may need to reload lab to apply changes made in `provision.sh` file in case if made any. 

```powershell
vagrant reload --provision
```
This reload may also ask for selecting network adapter to be used for hosting vm, **do not** input name of network adapter used by actual host, vagrant already will list all available adapter just above the prompted question.

Use numbers to answer and select he adapter eg: `1` ( for NAT adapter) & `2` for (Bridged Adapter)
</br>  

## Stopping the Lab

To stop the VM without removing it:

```bash
vagrant halt
```

Start it again with:

```bash
vagrant up
```

To completely remove the VM:

```bash
vagrant destroy -f
```

Note that the repository no longer relies on shared folders: `vagrant destroy` removes the VM, and a subsequent `vagrant up` rebuilds the environment entirely inside the VM.  
</br>

## Troubleshooting

**`vagrant up` fails with `Could not rename the directory '...' to '...\Northernbridge-College-CTF-v2' ... (VERR_ALREADY_EXISTS)`** (Windows/VirtualBox).

This happens when a previous `vagrant destroy` leaves a stale `Northernbridge-College-CTF-v2` folder behind (usually containing only `Logs/`). VirtualBox refuses to rename a fresh box import over it. Fix on the host:

```powershell
Remove-Item -LiteralPath "C:\Users\Dell\VirtualBox VMs\Northernbridge-College-CTF-v2" -Recurse -Force
vagrant up
```

If the `vagrant destroy` also leaves an orphaned registered VM (check with `VBoxManage list vms`), remove it as well:

```powershell
VBoxManage unregistervm "ubuntu-jammy-22.04-cloudimg-*" --delete
```
</br>  

**Alternative: manual removal**
* **step 1**: Open VirtualBox → Preferences → General → Default Machine Folder
* **Step 02**: visit the path displayed in `Default Machine Folder` in file explorer.
* **step 03**: select duplicate machines → delete
* **step 04**: Inside cloned repo folder eg: `C:\Users\user\Downloads\Northernbridge-College-CTF-2.0\` you may find `.vagrant` folder → select `.vagrant` → delete

**First `vagrant up` reports an SSH boot timeout but the VM keeps running.**

On slow disks the fresh box can take more than 10 minutes before the SSH service answers. Confirm the VM is `running` (`vagrant status`) and simply run `vagrant up` again — Vagrant continues from where it stopped and runs the provisioner.