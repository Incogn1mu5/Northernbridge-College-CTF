# Usage: Execute commands given below in sequence
# > powershell -ep bypass
# >.\regression-test.ps1 -TargetIP <VULN-IP / HARDN-IP>

param (
    [Parameter(Mandatory=$true)]
    [string]$TargetIP
)

$BaseUrl = "http://$TargetIP"

# Helper: Get HTTP Status Code without throwing terminating errors
function Get-StatusCode {
    param([string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 0 -ErrorAction Stop
        return [int]$resp.StatusCode
    } catch {
        if ($_.Exception.Response) {
            return [int]$_.Exception.Response.StatusCode
        }
        return 0
    }
}

# Helper: POST Request
function Post-Request {
    param([string]$Url, [hashtable]$Body, $Session = $null)
    try {
        if ($Session) {
            $resp = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -WebSession $Session -UseBasicParsing -MaximumRedirection 0 -ErrorAction Stop
        } else {
            $resp = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -UseBasicParsing -MaximumRedirection 0 -ErrorAction Stop
        }
        return $resp.Content
    } catch {
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            return $reader.ReadToEnd()
        }
        return ""
    }
}

# Helper: GET Request and extract response body
function Get-ResponseBody {
    param([string]$Url, $Session)
    try {
        $resp = Invoke-WebRequest -Uri $Url -WebSession $Session -UseBasicParsing -ErrorAction Stop
        return $resp.Content
    } catch {
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            return $reader.ReadToEnd()
        }
        return ""
    }
}

Write-Host "========================================================="
Write-Host " Starting Regression Test against $TargetIP"
Write-Host "========================================================="

# ---------------------------------------------------------
# UNAUTHENTICATED TESTS
# ---------------------------------------------------------

Write-Host "`n[NB-01] Testing Administrative Route Protection & Information Leakage..."
# Test if the unauthenticated index.php leaks the .env backup hint
$LoginBody = Get-ResponseBody -Url "$BaseUrl/admin/index.php" -Session $null

# CORRECTED REGEX: Looks for the forward slash (/) instead of a backslash
if ($LoginBody -match "backup: /\.env") {
    Write-Host "[-] VULNERABLE: /admin/index.php leaks information (<!-- backup: /.env -->)." -ForegroundColor Red
} else {
    Write-Host "[+] HARDENED: Unauthenticated login page leaks no internal paths." -ForegroundColor Green
}

Write-Host "`n[NB-02] Testing .env File Accessibility..."
$Status02 = Get-StatusCode -Url "$BaseUrl/.env"
if ($Status02 -eq 200) {
    Write-Host "[-] VULNERABLE: .env file is accessible over HTTP (HTTP 200)." -ForegroundColor Red
} else {
    Write-Host "[+] HARDENED: .env file is protected (HTTP $Status02)." -ForegroundColor Green
}

Write-Host "`n[NB-03] Testing Login Rate Limiting (Password Spraying)..."
$Resp03 = ""
for ($i = 1; $i -le 6; $i++) {
    $Resp03 = Post-Request -Url "$BaseUrl/admin/index.php" -Body @{ username="emma.novak"; password="WrongPassword123" }
}
if ($Resp03 -match "Too many attempts") {
    Write-Host "[+] HARDENED: Lockout mechanism engaged after 6 failed attempts." -ForegroundColor Green
} else {
    Write-Host "[-] VULNERABLE: No rate limit detected. Generic error returned on 6th attempt." -ForegroundColor Red
}

# ---------------------------------------------------------
# AUTHENTICATED TESTS
# ---------------------------------------------------------

Write-Host "`nLogging in to obtain session cookie..."
$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# Try Vulnerable Credential First
$LoginResp = Post-Request -Url "$BaseUrl/admin/index.php" -Body @{ username="helen.carter"; password="Winter2026!" } -Session $Session

# If it fails, try Hardened Credential
if ($LoginResp -match "Invalid administrator" -or $LoginResp -match "Too many attempts") {
    $Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $LoginResp = Post-Request -Url "$BaseUrl/admin/index.php" -Body @{ username="helen.carter"; password="Autumn2026!" } -Session $Session
}

if ($Session.Cookies.GetCookies($BaseUrl).Count -eq 0 -or $LoginResp -match "Invalid administrator") {
    Write-Host "ERROR: Failed to obtain session cookie. Skipping authenticated tests." -ForegroundColor Yellow
    exit
}

Write-Host "`n[NB-04] Testing Cross-Department Authorization (Restricted View)..."
$Resp004 = Get-ResponseBody -Url "$BaseUrl/admin/edit-marks.php?id=NB-VS26-1003" -Session $Session
$Resp04 = Get-ResponseBody -Url "$BaseUrl/admin/edit-marks.php?id=NB-VS26-3001" -Session $Session

if ($Resp004 -match "Student not found" -and $Resp04 -match "Student not found") {
    Write-Host "[+] HARDENED: Out-of-department student access rejected." -ForegroundColor Green
} else {
    Write-Host "[-] VULNERABLE: Successfully loaded out-of-department student form." -ForegroundColor Red
}

Write-Host "`n[NB-05] Testing SQL Injection in Search..."
$searchPayload = [uri]::EscapeDataString("' OR '1'='1")
$Resp05 = Get-ResponseBody -Url "$BaseUrl/admin/edit-marks.php?search=$searchPayload" -Session $Session
if ($Resp05 -match "Kavya Singh") {
    Write-Host "[-] VULNERABLE: SQL Injection successful. Unauthorized schema/rows dumped." -ForegroundColor Red
} else {
    Write-Host "[+] HARDENED: SQL Injection rejected. Payload treated as literal text." -ForegroundColor Green
}

Write-Host "`n[NB-06] Testing Local File Inclusion (LFI)..."
$Resp06 = Get-ResponseBody -Url "$BaseUrl/admin/edit-marks.php?id=/etc/passwd" -Session $Session
if ($Resp06 -match "root:x:0:0:") {
    Write-Host "[-] VULNERABLE: LFI successful. Read /etc/passwd." -ForegroundColor Red
} else {
    Write-Host "[+] HARDENED: LFI rejected. Arbitrary file read prevented." -ForegroundColor Green
}

Write-Host "`n========================================================="
Write-Host " Regression Test Complete"
Write-Host "========================================================="
