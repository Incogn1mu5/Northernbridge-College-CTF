# Northenbridge College CTF Lab

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/690b82d45d6b85256f887baf3a61708418665052/Screenshots/Assets/Hacker4Help_Logo-White.png">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/690b82d45d6b85256f887baf3a61708418665052/Screenshots/Assets/Hacker4Help_Logo-Black.png">
  <img align="right" alt="Hacker4Help" src="https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/690b82d45d6b85256f887baf3a61708418665052/Screenshots/Assets/Hacker4Help_Logo-Black.png" width="140">
</picture>

### About This Project

A fictional college web portal built as a beginner-friendly Capture The Flag (CTF) lab developed as part of an internship with **&lt;/Hacker4Help&gt;**, a company focused on Offensive & Defensive security training. This repository: Northenbridge-College-CTF lab — showcases hands-on
work done on the second version of CTF Lab during the internship.

**Company:**[&lt;/Hacker4Help&gt;](https://hacker4help.com)

---

The project combines a simple student portal with an intentionally vulnerable administrative portal. Players are expected to explore the application, follow clues, discover hidden functionality, and eventually dump database and follow clue to find final secrete flag and complete the challenge.

> [!CAUTION]
> This project is an intentionally vulnerable Capture The Flag (CTF) educational sandbox. The code, architecture and configurations within this repository are designed specifically for security training and **doesn't** reflect the production engineering or security standards of **<a href="https://github.com/hacker4help">&lt;/Hacker4Help&gt;</a>** team.  Do not deploy this on an untrusted or public network.  
</br>  

## Features

### Student Portal

* Student registration
* Automatic student credential generation
* Credential download
* Student login/logout
* Profile viewing and editing
* Personal marks and result status
* Reassessment functionality containing a CTF clue

### Admin Portal

* Separate administrator login
* Student record dashboard
* Student marks management
* Limited student-record visibility
* Intentionally vulnerable search functionality
* Hidden CTF flags throughout the challenge

### Other

* College Homepage
* College Academics page
* Events page
* Contact and About page  
</br>

## CTF Challenge

The challenge is designed around a simple progression:

```text
Student Portal
      │
      ▼
Registration & Login
      │
      ▼
Directory Enumeration
      │
      ▼
Discover hidden Admin portal and .env decoy file
      │
      ▼
Credential Discovery under .env file
      │
      ▼
Access Admin Dashboard
      │
      ▼
Limited Student Records visible
      │
      ▼
SQL Injection
      │
      ▼
Discover Player Record
      │
      ▼
Dump database using SQLi
      │
      ▼
Discover clue for final flag under compliance notes
      │
      ▼
Local File Inclusion
      │
      ▼
Final Flag
```

The challenge contains **four flags**, with each stage leading toward the next part of the application.

For the detailed challenge flow, see [CTF-Design_&_Challenge-Flow.md](https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/690b82d45d6b85256f887baf3a61708418665052/Docs/CTF%20Design_%26_Challenge-Flow.md).  
</br>  

## Technology Stack

* **Vagrant** — VM provisioning
* **VirtualBox** — virtualization
* **Ubuntu 24.04** — guest operating system
* **Apache2** — web server
* **PHP** — application
* **SQLite** — database
* **Bash** — provisioning

The project uses shared folders so that the web application can be edited directly from the host machine.  
</br>  

## Project Structure

```text
  Northenbridge-College-CTF(v2.0)/    
  ├── README.md                       
  ├── Vagrantfile                     
  ├── seed.sql                        
  ├── infra/                          
  │   └── provision.sh
  │               
  ├── www/                            
  │   ├── index.php                   
  │   ├── academics.php               
  │   ├── admissions.php              
  │   ├── contact.php                 
  │   ├── about.php                   
  │   ├── events.php                  
  │   ├── login.php                   
  │   ├── register.php                
  │   ├── profile.php                 
  │   ├── marks.php                   
  │   ├── logout.php                  
  │   ├── db.php                      
  │   ├── 404.html                    
  │   ├── 500.html                    
  │   ├── .env
  │   ├── .htaccess
  │   │                   
  │   ├── admin/                      
  │   │   ├── index.php               
  │   │   ├── dashboard.php           
  │   │   ├── edit-marks.php          
  │   │   └── logout.php
  │   │            
  │   └── includes/                   
  │       ├── adm-header.php          
  │       ├── adm-footer.php          
  │       ├── header.php              
  │       ├── footer,php              
  │       └── init.php
  │                
  ├── docs/                           
  │   ├── Architecture.md             
  │   ├── CTF-Design_&_Challenge-Flow.md                 
  │   ├── Deployment.md
  │   └── Vulnerabilities_&_Testing.md
  │
  ├── scenarios/
  │   ├── Instructor-Guide.md             
  │   ├── Student-Guide.md                 
  │   ├── Learning-Objectives.md
  │   └── Documentation-Review-Note.md
  │
  └── Screenshots/                    
      ├── homepage.png                
      ├── student-portal.png          
      ├── marks-page.png              
      └── admin-dashboard.png         
```  
</br>  

## Screenshots

### College Homepage

<img width="2235" height="865" alt="Home Page" src="https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/690b82d45d6b85256f887baf3a61708418665052/Screenshots/NCC_Home-page.png" />  

### Student Portal

<img width="2235" height="865" alt="Student Login Page" src="https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/690b82d45d6b85256f887baf3a61708418665052/Screenshots/NCC_Student-login-page.png" />  

### Student Marks

<img width="2235" height="865" alt="Student Marks Page" src="https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/690b82d45d6b85256f887baf3a61708418665052/Screenshots/NCC_Student-exam-result-page.png" />  
</br>  

## Deployment

The lab runs inside a Vagrant-managed Ubuntu VM.

### Requirements

Install the following on the host machine:

* VirtualBox
* Vagrant
* Git

### Start the Lab

Clone the repository and start the VM:

```powershell
git clone <repository-url>
cd Northenbridge-College-CTF-2.0
vagrant up
```

The provisioning script installs Apache, PHP, SQLite and the required PHP SQLite extension, configures the virtual host, and initializes the database from `seed.sql`.

### Find the VM IP

The VM uses **bridged networking**, allowing other devices on the same local network to access the CTF.

Run:

```powershell
vagrant ssh
hostname -I
```

Use the VM's LAN address from another device:

```text
http://<VM-IP>/
```

For example:

```text
http://192.168.1.50/
```

The exact IP will depend on the local network.

### Stop lab
```powershell
vagrant halt
```

### Start Lab in Development Mode
set variable in powershell
```powershell
$env:DEV_MODE="1"
```
use vagrant to spin up vm lab in dev mode
```powershell
vagrant up
```

### Multi-Player Access

The intended setup is:

```text
                 Local Network
                       │
        ┌──────────────┼──────────────┐
        │              │              │
     Player 1       Player 2       Player 3
        │              │              │
        └──────────────┼──────────────┘
                       │
                Host Computer
                       │
                VirtualBox VM
                       │
                Apache + PHP
                       │
                  SQLite DB
```

Only the host computer needs to run the VM. Players connect to the VM's bridged IP from devices connected to the same network.
More deployment details are available in [Deployment.md](https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/690b82d45d6b85256f887baf3a61708418665052/Docs/Deployment.md).  
</br>  

## Resetting the Lab

To completely recreate the VM:

```bash
vagrant destroy -f
vagrant up
```

The provisioning process recreates the application environment and seeds the SQLite database inside VM.  
</br>  

## Intentional Vulnerabilities

The vulnerabilities are deliberately included as part of the CTF and are restricted to the fictional application.

The main challenge elements include:

* Hidden administrative route
* Information disclosure through `.env` file
* Limited student-record visibility
* SQL injection in the administrative search
* Local File Inclusion to retrieve system file

The marks update itself uses a prepared SQL statement; the intentional SQL injection is in the student-record search functionality.

Detailed testing information is available in [Vulnerabilities_&_Testing.md](https://github.com/Incogn1mu5/Northernbridge-College-CTF/blob/690b82d45d6b85256f887baf3a61708418665052/Docs/Vulnerabilities_%26_Testing.md).
</br>  

## Documentation

| Document | Audience | Description |
|---|---|---|
| [Instructor Guide](Scenarios/NCC_Instructor-Guide.md) | Instructor / reviewer only | Full solution path, flag locations, timing plan, reset procedure, troubleshooting, and safety briefing. **Contains solutions — do not hand to students.** |
| [Student Lab Guide](Scenarios/NCC_Student-Guide.md) | Students | Objective, rules of engagement, staged hints, submission flow, and reflection questions. **No solutions.** |
| [Learning Objectives & Real-World Impact](Scenarios/NCC_Learning-Objectives.md) | Students + instructor + curriculum reviewers | Per-stage concept, lab demonstration, learning outcomes, real-world impact, and remediation guidance. |
| [Documentation Review Note](Scenarios/NCC_Documentation-Review-Notes.md) | Reviewer | Self-review against the Phase 4 checklist plus verification test evidence. |
| [Architecture](Docs/Architecture.md) | Instructor / developer | VM, networking, web server, database, and application structure. |
| [CTF Design & Challenge Flow](Docs/CTF-Design_&_Challenge-Flow.md) | Instructor / developer | Stage-by-stage design, flag table, and intended learning outcomes. |
| [Deployment](Docs/Deployment.md) | Instructor / developer | Normal and development deployment modes, provisioning, and reset. |
| [Vulnerabilities & Testing](Docs/Vulnerabilities_&_Testing.md) | Instructor / developer | Intentional vulnerability locations and test results. |

> **Instructor note:** The instructor walkthrough is the only document that contains the full solution path. Keep it out of student hands. The student guide is designed to be handed out at the start of the session.
---

## Contributors

Thanks to everyone who contributed to this project:

- [@Incogn1mu5](https://github.com/username1)
- [@priyanshi-halpani](https://github.com/priyanshi-halpani)