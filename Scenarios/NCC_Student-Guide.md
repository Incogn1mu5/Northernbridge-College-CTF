# Northernbridge-College-CTF — Student Lab Guide

**Duration:** ~2 hours · **Difficulty:** Beginner · **Format:** Individual or pairs

You have been asked to assess whether the fictional Northernbridge College Portal is exposing data it should not. Your job is to find out what is wrong with it, how far the exposure goes, and what a real organization should do about it.  
</br>  

## 1. Rules of engagement

- Stay inside the lab. The target is the VM your instructor gave you.
- Do not scan, probe, or attack anything outside the lab — not the host machine, not the local network, not any real website.
- Do not use real credentials anywhere, including your own.
- Everything on the lab is fictional data. Treat it that way.
- If you are stuck, ask for a hint. Do not guess wildly against the network.
- Take notes. Your notes are your record of the assessment.  
</br>  

## 2. What you are trying to achieve

Assess the portal and determine the full extent of any data exposure. Each stage adds a piece of the picture. At the end you will submit your findings and write a short reflection.

The flag format will be explained by your instructor.  
</br>  

## 3. Environment

- **Target URL:** `http://<vm-ip>/` — your instructor will confirm the exact address. On a single‑player host it may be `http://vm-Bridged-IP/` or `http://vm-NAT-IP/`.
- The VM is local. You may use additional tools already installed on your machine beyond a browser.
- Student credentials are generated when you register.
- Submit flags through the platform your instructor specifies.  
</br>  

## 4. Getting oriented

- Load the homepage. Click through every page. Read the HTML source of the pages you visit — that is normal when assessing a web application.
- Not everything the site does is advertised in the navigation. A page can exist without being linked.
- When a page returns "not found", check whether you are looking at the site's branded 404 or something else. The difference tells you whether a route exists.
- Observe before you exploit. Write down what you see, then decide what to try.
- Read the error messages carefully. In this lab the useful information is usually in what the site does **not** say.  
</br>  

## 5. Staged hints

Each stage has three hints. Read them in order. Try the stage before
reading the next hint. No hint contains the answer.

> <h3>Stage 1 — Find the hidden staff area</h3>

1. **Where to look.** What pages does the site link to? What pages doesn’t it?
2. **What to observe.** The navigation is complete for the features it advertises — and silent about everything else.
3. **How to reason.** If a page exists but is not linked, it is still a page. Try the obvious names for staff areas.

> <h3>Stage 2 — The exposed file</h3>

1. **Where to look.** Look for files a well‑configured site should not serve over HTTP. Some are not linked and are not meant to be readable.
2. **What to observe.** One such file lists several accounts. Most will not work. The login reply is the same for every wrong pair.
3. **How to reason.** A list of credentials is only useful if you try them all systematically. Do not stop at the first failure.

> <h3>Stage 3 — The staff dashboard</h3>

1. **Where to look.** You have just landed somewhere new. Read the page before you click anything else.
2. **What to observe.** What does this page assume about what you are allowed to do?
3. **How to reason.** A login that succeeds is not the same as a login that should have succeeded. Note what you can and cannot see.

> <h3>Stage 4 — The short list</h3>

1. **Where to look.** The record view. Count the rows.
2. **What to observe.** The view shows a few records, all from one department. Your own student record is not among them.
3. **How to reason.** A view that is limited by default is not necessarily limited everywhere. Ask yourself where the limit is actually applied.

> <h3>Stage 5 — The search box</h3>

1. **Where to look.** The record search is the only input that changes what you see. Start there.
2. **What to observe.** Normal text returns normal rows. Some inputs change the shape of the results in ways a text search should not.
3. **How to reason.** If the search is building a query out of your input, you can change the query's logic. Follow that through to the metadata and the notes table, then read the file the notes point to.

> <h3>Stage 6 — Outside the database</h3>

1. **Where to look.** The other parameter on the same page — the one that fetches a single record.
2. **What to observe.** The parameter treats different kinds of values in different ways.
3. **How to reason.** One of those kinds of value is not a student ID at all. If the application is willing to read it, follow it to the file the notes told you about.  
</br>  

## 6. Submission and scoring

- Submit each flag as you find it, through the platform your instructor specifies.
- Hints are free unless your instructor says otherwise.
- You must submit a written reflection at the end (see below).
- Do not paste flag values into public chat.  
</br>  

## 7. Final reflection (write in prose, ~1 page)

Answer all four:

1. Which component of the application was affected at each stage, and what was wrong with it?
2. Who could have been harmed by this, and how?
3. What is the single change you would make to fix the most serious issue you found?
4. What is one *other* place in the same application where the same kind of mistake might exist?  
</br>  

## 8. Reset policy

The lab is reset between sessions by the instructor. Your notes are your own record; the environment is not. If you break the site while testing, tell the instructor.
