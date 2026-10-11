# Northernbridge College CTF - Architecture 
## 1. Overview

Northernbridge College CTF is a fictional college web portal designed as a beginner-friendly, intentionally vulnerable cybersecurity lab.

The project uses:

* **Vagrant 2.4.9** for creating and provisioning the VM
* **Ubuntu/jammy64** as the VM operating system
* **Apache 2.4.58** as the web server
* **PHP 8.3.6** for the application
* **SQLite 3.45.1** for the database
* **VirtualBox 7.2.4** as the Vagrant provider

The lab is provisioned using Vagrant the environment can be recreated this project repository.

The application contains two main areas:

- Student Portal : registration, authentication, profile management, and personal examination results.
- Administration Portal : administrator authentication, student-record search, and marks management.


## 2. Architecture

```
CTF Player01    CTF Player02      ....
    └────────────────┼──────────────┘ 
                     │                
                     ▼                
          Access College Website      
         ┌───────────────────────┐    
         │http://vm-Bridged-IP/  │    
         ├───────────────────────┤    
         │ Northernbridge College │    
         └───────────────────────┘    
                     ▲                
                     │                
                     │                
    ┌───────── Bridge Network ───────┐
    │                │               │
    │    ┌───────────┼──────────┐    │
    │    │    "northernbridge"   │    │
    │    │           │          │    │
    │    │ ┌─────────┼───────┐  │    │
    │    │ │        PHP   SQLite│    │
    │    │Apache    App     DB  │    │
    │    │ ▲         ▲        ▲ │    │
    │    │ └─────────┼────────┘ │    │
    │    │           │          │    │
    │    │       Ubuntu VM      │    │
    │    │           ▲          │    │
    │    │           │          │    │
    │    │           ▼          │    │
    │    │ VirtualBox + Vagrant │    │
    │    └──────────────────────┘    │
    │          CTF Host PC           │
    └────────────────────────────────┘
```
Only the CTF host needs to run Vagrant, VirtualBox, Ubuntu, Apache, PHP, and the database.

Player devices only need a web browser and network access to the CTF host.  
</br>

## 3. Virtual Machine

The lab uses a single Vagrant-managed Ubuntu virtual machine.

VM Components|Configuration
-|-
Vagrant box | ubuntu/jammy64
Provider | Virtual Box 7.2.4
Hostname | northernbridge
VirtualBox VM name | northernbridge-ctf
Memory | 2048 MB
CPUs | 2
Web server | Apache2 (2.4.58)
Application runtime | PHP 8.3.6
Database | SQLite 3.45.1
HTTP port| 80

The VM is intentionally kept simple so that the complete CTF can run from one machine.  
</br>  

## 4. Networking

The current Vagrant configuration hosts website directly on LAN using bridge network mode. For multiple players, the VM can be connected to the same LAN as the player devices using bridged networking.

```
┌─────────────┬───────────────────┐
│Local Network│                   │
├─────────────┘                   │
│                                 │
│  Player      Player      Player │
│  Device      Device      Device │
│    1           2           3    │
│    └───────────┼───────────┘    │
│                ▼                │
│      Northernbridge College      │
│             Website             │
│                ▲                │
│                │                │
│           Apache :80            │
│                ▲                │
│                │                │
│          VirtualBox VM          │
│                ▲                │
│                │                │
│           CTF Host PC           │
└─────────────────────────────────┘
```

Players access the application using the VM's LAN address:

``` URL
http://<VM-IP>:80
```

The northernbridge.local Apache ServerName does not automatically provide DNS resolution to player devices, so the IP address is the simplest event access method unless local DNS is configured.

The vulnerable application should remain on a controlled/private network and must not be exposed to the public internet.  
</br>  

## 5. Deployement

The project uses normal mode and development mode. Normal mode (provisioning-only) is default mode which performs update, configurations entirely inside VM and this mode doesn't depends on host. Development mode uses Vagrant synced folders if CTF host enables Development mode using `$env:DEV_MODE="1"` and then `vagrant up`. Both `/vagrant` and the `./www` mount are use in the `Vagrantfile` only if CTF host choose to deploy lab in dev-mode to make changes on webpages.

### 1. Normal Mode — Git-based deployment
```text
                        Project root (clone anywhere)

Windows host
├── Vagrantfile
├── seed.sql
└── infra/provision.sh — single source of truth
                                          ▼ 
                           vagrant up / vagrant provision
                           Provisioning executes inside Ubuntu VM
                                          ▼ 

Inside the VM

1. Install Apache, PHP, SQLite, Git, cURL and rsync dependencies.
2. Clone PORTAL_REPO:PORTAL_BRANCH into /opt/northernbridge-src.
3. Rsync $PORTAL_SUBDIR (www) into /var/www/html, excluding the database directory.
4. Configure Apache virtual host for http://northernbridge.local/.
5. Write the decoy .env file into /var/www/html/.env.
6. Create /opt/northernbridge/flag.txt outside the web root.
7. Seed SQLite from seed.sql, skipping initialization if tables already exist.
8. Restart Apache and verify HTTP 200 on 127.0.0.1:80 inside the VM.
```

Deployment flow:
```text
Windows host
  └── Project root
       ├── Vagrantfile
       ├── seed.sql
       └── infra/provision.sh
                │
                ▼
          Ubuntu VM
                │
                ├── Git clone → /opt/northernbridge-src
                ├── Rsync     → /var/www/html
                ├── SQLite    → application database
                ├── Flag 04   → /opt/northernbridge/flag.txt
                └── Apache    → northernbridge.local
```

In this mode, the Git repository is the source of the application code deployed into the VM. Changes made to the host's application files do not automatically update the deployed site.  
</br>

### 2. Development Mode — Shared-folder deployment

Development mode is intended to let you edit your website files on Windows while Apache serves them from the Ubuntu VM, without having to clone and copy the application code on every change.
```text
                                 Project root (clone anywhere)

Windows host — editable application source
├── Vagrantfile
├── seed.sql
├── infra/provision.sh — single source of truth
└── www/ — application source
      └── PHP pages, other application files
                                ▼
                     DEV_MODE=1 + vagrant up
                  Host directory shared with the VM
                                ▼
Inside the VM

1. Install the required system packages.
2. Configure the development-mode application source path or shared folder.
3. Make the host's application files available directly to Apache, rather than relying on a fresh Git clone and rsync for each edit.
4. Configure Apache for http://northernbridge.local/.
5. Initialize SQLite from seed.sql when the database tables do not already exist.
6. Restart Apache and verify HTTP 200 on 127.0.0.1:80 inside the VM.
```

Development deployment flow:
``` text
Windows host
  └── Project root
       ├── Vagrantfile
       ├── seed.sql
       ├── infra/provision.sh
       └── www/
            └── PHP pages, CSS, JS and assets
                   │
                   │ Shared folder / development source
                   ▼
                Ubuntu VM
                   │
                   ├── Apache  → shared application files
                   ├── SQLite  → application database
                   ├── Flag 04 → /opt/northernbridge/flag.txt
                   └── Vhost   → northernbridge.local
```



The `www` directory in the repository is the portal application source (the "northernbridge-portal" content). At runtime it is served from `/var/www/html` inside the VM and is fully independent of the host filesystem — host edits only reach the VM if development mode is enabled before deploying lab.  
</br>

## 6. Web Server

Apache serves the application from:

```
/var/www/html
```
The Vagrant provisioning script creates an Apache virtual-host configuration for the application.

The relevant service path is:

```
HTTP request
     │
     ▼
Apache *:80
     │
     ▼
/var/www/html
     │
     ├── admissions.php
     ├── academics.php
     ├── about.php
     ├── contact.php
     ├── events.php
     ├── index.php
     ├── register.php
     ├── login.php
     ├── profile.php
     ├── marks.php
     └── admin/
```

Apache is responsible only for serving the PHP application and static resources. The CTF vulnerabilities are implemented in the application itself rather than by weakening the host operating system.  
</br>  

## 7. Application Structure

**Student Portal**

The student-facing application contains:

```
/
├── admissions.php
├── academics.php
├── about.php
├── contact.php
├── events.php
├── index.php
├── register.php
├── login.php
├── profile.php
├── marks.php
├── logout.php
├── db.php
└── .env
```

**Student workflow**

```
Homepage
   │
   ▼
Registration
   │
   ▼
Credentials generated
   │
   ▼
Student Login
   │
   ▼
Profile
   │
   ▼
Marks
```

The registration process generates a fictional student ID, institutional email address, and password based on the submitted registration information.
</br>  

## 8. Administration Portal

The administrator area is located under:

```
/admin/
```
The implemented administration pages include:
```
/admin/
├── index.php
├── dashboard.php
├── edit-marks.php
└── logout.php

```

The administration portal is not presented as a normal student navigation option.

The portal provides:

- Administrator authentication
- Administrator dashboard
- Student-record overview
- Student marks editing
- Student search

The normal record view intentionally exposes only a subset of the available fictional records.  
</br>  

## 9. Database Architecture

SQLite is used as the application database.

The database contains the principal tables:
```
┌──────────────┐
│   students   │
└──────┬───────┘
       │
       │ student_id
       │
       ▼
┌──────────────┐
│     marks    │
└──────────────┘

┌──────────────┐
│    admins    │
└──────────────┘

┌──────────────┐
│     flags    │
└──────────────┘
```
</br>  

**Students**

The students table contains fictional student information including:

- Student ID
- First name
- Last name
- Contact number
- Date of birth
- Address
- Department
- Email
- Password

**Marks**

The marks table contains examination marks associated with student IDs.

The implemented subjects include:

- Mathematics
- C++
- Python
- Graphics

**Admins**

The admins table stores fictional administrator accounts used by the CTF lab.

**Flags**

The flags table stores the CTF flags used by the application. The actual flag values tell player about what vulnerability is exploited. 
</br>  

## 10. Database Initialization

The database is initialized from `seed.sql` by `infra/provision.sh`.

The provisioning process:

1. Installs SQLite and PHP SQLite support.
2. Clones the portal source and installs it into `/var/www/html`.
3. Creates the application database directory.
4. Creates the SQLite database and executes the seed SQL **only when the database is empty** (the seed is written with `CREATE TABLE IF NOT EXISTS` and `INSERT OR IGNORE`, so it is idempotent and re-provisioning never wipes player data).
5. Assigns the database directory to the Apache `www-data` user.
6. Sets appropriate permissions for the application to access the database.

The seed file provides the fictional students, marks, administrator account, and the in-application CTF flags.

The **final** flag is deliberately placed outside the database by the provisioning script, at `/opt/northernbridge/flag.txt`.  
</br>  

## 11. Application Data Flow

**Student registration**
CTF player registers as a student and receives credentials generated. All student record and generated credentials are inserted into database.

```
Student
   │
   ▼
register.php
   │
   ├── Validate registration data
   │
   ├── Generate student ID
   ├── Generate institutional email
   ├── Generate password
   └── Insert student + initial marks
             │
             ▼
          SQLite
```

**Student login**
Once student register, fictional marks are inserted into database along with student information. On successfull login, student is redirected to profile page, where student can change name, contact number and residential address which gets saved directly on databse.

```
Student Login
     │
     ▼
 login.php 
     │
     ▼
   SQLite
     │
     ▼
 Session 
     │
     ▼
 proflle.php
     │
     ▼
  SQLite     
     │
     ▼
Student's Info
```

**Student marks**
```
Student Profile
     │
     ▼
 Exam Result
     │
     ▼
 marks.php
     │
     ▼
  SQLite
     │
     ▼
 Student marks
```

**Administrator marks management**
The administrator search functionality is intentionally unsafe in one specific search path. This is the SQL injection stage of the CTF.

```
Administrator
      │
      ▼
 /admin/index.php
      │
      ▼
 /admin/dashboard.php
      │
      ▼
 /admin/edit-marks.php
      │
      ▼
    SQLite
``` 
</br>  

## 12. Security Boundaries

The lab has several deliberate boundaries.

**Student boundary**

A normal student should be able to:

- Register
- Log in
- View their profile
- Update permitted profile information
- View their own marks

**Administrator boundary**

An authenticated administrator can:

- Access the administration dashboard
- Search student records
- Edit marks

The CTF intentionally introduces weaknesses that allow a player to discover and cross these application-level boundaries.

The host operating system, Vagrant configuration, SSH service, and unrelated system services are not intended targets.  
</br>  

## 13. Intentional Vulnerability Locations

The implemented CTF contains six main stages:

Stage| Areas of Application | Intended lesson
-|-|-
1 | Hidden /admin route | Hidden routes are not access control
2 | Web-accessible decoy sprayable .env file | Sensitive information should not be exposed through web files
3 | Limited administrator record view |	Understand application-side record restrictions
4 | Investigate the Unsafe Search (`search=`) | Concatenating user input into SQL lets an attacker alter the application's intended query logic
5 | Database Exfiltration | Data disclosed through injection can itself be the reconnaissance step that enables a second, unrelated vulnerability
6 | Local File Inclusion to access system files via (`id=`)| Improper file path validation can allow attackers to read sensitive local files outside the intended application directory

The SQL injection weakness is intentionally restricted to the fictional student database.
No host-level exploitation is required to complete the CTF.  
</br>

## 14. Reset and Reproducibility

The environment is designed to be reproducible using Vagrant and the provisioning script.

The seed database provides the known initial application state.

A reset should restore:

- Student records
- Administrator records
- Marks
- CTF flags
- Application state
- Filesystem artifacts (decoy `.env`, final flag)

Re-running `vagrant provision` against a live VM does **not** restore the database (seeding is skipped once tables exist); use `vagrant destroy -f && vagrant up` for a true reset.  
</br>

## 15. Multi-Player Considerations

The current application uses a shared SQLite database.

Therefore, when multiple players use one running VM:
```
Player A ─┐
Player B ─┤
Player C ─┼──► Same Apache ──► Same SQLite DB
Player D ─┘
```

All players interact with the same application state, but it means that changes made by one player can potentially affect what another player sees. In particular, the marks-editing stage modifies database records. Therefore host should be monitored.