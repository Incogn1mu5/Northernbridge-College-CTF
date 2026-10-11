# Vulnerabilities and Testing

The vulnerabilities in this project are intentional and are limited to the fictional Northernbridge College application.

The tests below verify that the intended CTF path works without relying on unrelated system weaknesses.  
</br>  

## 1. Hidden Admin Route

### Location

```text
/admin/
```

The admin portal is not included in the normal student navigation.

The player needs to perform directory enumeration and discover hidden `/admin` route.

### Expected Result

A player can reach the admin login page and obtain the `Flag 01`.  
</br>  

## 2. Exposed Credentials

### Location

```text
/.env
```
The only hint in served HTML is the comment <!-- backup: /.env --> on www/admin/index.php — must never appear on any public page. 
The file contains fictional faculty credentials used by the challenge.

### Expected Result

A player who discovers the file can use the credentials to log into the admin portal.

No real credentials are used by the project.  
</br>  

## 3. Limited Student Records

### Location

```text
/admin/dashboard.php
/admin/edit-marks.php
```

The admin dashboard only displays a limited number of student records. Player discovers `Flag 02` on `/admin/dashboard.php`

The marks management page also applies a restriction to the normal search results.

The student created during the CTF is not normally visible in this list.

### Expected Result

The player can identify that the visible records are incomplete and continue investigating the search functionality.  
</br>  

## 4. Intended Student Search Restriction

### Location
> 🔍 search bar

The student marks management page intentionally restricts normal search results to only fetch records whose student ID begins with `NB-`.

This means that when an administrator performs a normal search using either student full name or exact student ID (eg: NC-AP26-0001), only the pre-existing `NB-*` student records are returned. A newly registered player receives an `NC-*` student ID and therefore does not appear in the normal search results.

This restriction is part of the CTF design rather than a database limitation.

The search query is intentionally vulnerable to SQL injection. By manipulating the search input, a player can bypass the `NB-*` restriction and cause additional records, including the player's `NC-*` record, to appear.

The intended progression is:

```text
Normal Search
     │
     ▼
Only NB-* records visible
     │
     ▼
Player's NC-* record is missing
     │
     ▼
Investigate the search functionality
     │
     ▼
SQL Injection
     │
     ▼
NB-* restriction bypassed
     │
     ▼
NC-* player record discovered
     │
     ▼
edit marks → NC-* student
     │
     ▼
Flag 03
```
</br>  

## 5. SQL Injection

### Location

```text
/admin/edit-marks.php
```

The student search query intentionally uses the supplied search value directly when constructing the SQL query.

The vulnerable search is the main database-related weakness in the CTF.

The actual marks update operation uses a prepared statement; the intended weakness is the discovery/search functionality.

### Expected Result

A player can manipulate the search input to bypass the normal student ID restriction and discover additional fictional records.

The player's own student ID can then be used with the marks editing interface.  
</br>  

## 6. Local File Inclusion

Once the player's student record has been discovered, the marks editing interface, player needs to dump all database table and look for clue in of the table.

The same parameter which fetches the student record can also fetch system-files.



### Expected Result

After finding clue for final flag, LFI technique can be used to retrieve system files and display it on webapp which will display Final `Flag 04`  
</br>  

# Testing

## Basic Application Test

* [x] Home-page loads.
* [x] Events-page loads.
* [x] Academics-page loads.
* [x] Admissions-page loads.
* [x] About-page loads.
* [x] Contact-page loads.
* [x] Student registration works.
* [x] Credential file downloads successfully.
* [x] Student can log in.
* [x] Profile page loads.
* [x] Student marks are displayed.
* [x] Initial result is failed.
* [x] Clue for `.env` placed in source page on `/index.php` 
* [x] Directory Enumeration discloses hidden `/admin` route.
* [x] Student logout works.

## Admin Test

* [x] `/admin` loads the admin login page.
* [x] Admin credentials from the intended challenge file work.
* [x] Admin dashboard loads after login.
* [x] Limited student records are displayed.
* [x] Marks management page loads.
* [x] Existing student marks can be edited.
* [x] Updated marks are saved correctly.
* [x] Admin logout works.

## CTF Path Test

* [x] Flag 01 is available from the hidden admin route.
* [x] Flag 02 is available after successful login and access to admin dashboard.
* [x] Flag 03 is available during the limited-record stage.
* [x] SQL injection allows the intended additional records to be discovered.
* [x] The player's student record can be identified.
* [x] SQL injection allows the player to dump metadata of database.
* [x] Database has clue for Final Flag.
* [x] Final `Flag 04` present outside the database and stored on system with unique token value.
* [x] Local File Inclusion works and retrieves intended flag.txt from systemfiles. 

## Network Test

With bridged networking enabled:

* [x] VM receives an address on the local network.
* [x] Website is reachable from the host using the VM IP.
* [x] Website is reachable from a second device on the same network.
* [x] Multiple devices can load the website at the same time.
* [x] Student registration works while another player is using the site.
* [x] Admin pages remain accessible during normal player activity.

The CTF should be tested with several devices before the actual session, especially because all players use the same application and database.