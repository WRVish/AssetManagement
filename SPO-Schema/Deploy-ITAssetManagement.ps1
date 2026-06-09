<#
.SYNOPSIS
    IT Asset Management - SharePoint List Provisioning and Data Import

.DESCRIPTION
    Creates all 6 SharePoint lists for the IT Asset Management Power App,
    provisions columns with correct types, and bulk-imports test data.
    Uses UseWebLogin for authentication. Safe to re-run - existing items
    are skipped to avoid duplicates.

.NOTES
    Requires : PnP.PowerShell v1.12.0
    Install  : Install-Module PnP.PowerShell -RequiredVersion 1.12.0 -Scope CurrentUser -Force -AllowClobber
    Auth     : Uses UseWebLogin (browser pop-up)
    Author   : Vishnu WR - wrvishnu.com
    Version  : 1.1
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [string]$SiteUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptVersion = "1.1"

# ============================================================
# USERS — update these to match your tenant UPNs
# ============================================================
$U_SuperAdmin = "vishnu@vishtechtalk.onmicrosoft.com"
$U_ITAdmin    = "HelpdeskRead@vishtechtalk.onmicrosoft.com"
$U_ReadOnly   = "Helpdesk1@vishtechtalk.onmicrosoft.com"
$U_User1      = "user1@vishtechtalk.onmicrosoft.com"
$U_User2      = "user2@vishtechtalk.onmicrosoft.com"
$U_User3      = "user3@vishtechtalk.onmicrosoft.com"
$U_User4      = "user4@vishtechtalk.onmicrosoft.com"
$U_User5      = "user5@vishtechtalk.onmicrosoft.com"

# ============================================================
# OUTPUT HELPERS
# ============================================================
function Write-Banner {
    param([string]$Text)
    $line = "=" * 60
    Write-Host ""
    Write-Host $line        -ForegroundColor Cyan
    Write-Host "  $Text"    -ForegroundColor Cyan
    Write-Host $line        -ForegroundColor Cyan
}
function Write-Step { param([string]$t); Write-Host "  >> $t"        -ForegroundColor White  }
function Write-OK   { param([string]$t); Write-Host "     [OK]   $t" -ForegroundColor Green  }
function Write-Warn { param([string]$t); Write-Host "     [WARN] $t" -ForegroundColor Yellow }
function Write-Fail { param([string]$t); Write-Host "     [FAIL] $t" -ForegroundColor Red    }

# ============================================================
# PRE-FLIGHT CHECKS
# ============================================================
function Invoke-PreflightChecks {
    param([string]$Url)
    Write-Banner "Pre-flight Checks"
    $pass = $true

    Write-Step "PowerShell version"
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Write-OK "PowerShell $($PSVersionTable.PSVersion)"
    } else {
        Write-Fail "PowerShell 5.1 or higher required"
        $pass = $false
    }

    Write-Step "PnP.PowerShell module"
    $mod = Get-Module -ListAvailable -Name "PnP.PowerShell" |
           Sort-Object Version -Descending | Select-Object -First 1
    if ($null -ne $mod) {
        Write-OK "PnP.PowerShell v$($mod.Version) found"
    } else {
        Write-Fail "PnP.PowerShell not found. Run: Install-Module PnP.PowerShell -RequiredVersion 1.12.0 -Scope CurrentUser -Force -AllowClobber"
        $pass = $false
    }

    Write-Step "Site URL format"
    if ($Url -match "^https://[a-zA-Z0-9\-]+\.sharepoint\.com/") {
        Write-OK "URL format valid"
    } else {
        Write-Fail "URL does not look like a SharePoint Online URL: $Url"
        $pass = $false
    }

    Write-Step "Network connectivity"
    try {
        $uri  = [System.Uri]$Url
        $req  = [System.Net.WebRequest]::Create("$($uri.Scheme)://$($uri.Host)")
        $req.Method  = "HEAD"
        $req.Timeout = 10000
        $resp = $req.GetResponse()
        $resp.Close()
        Write-OK "Host reachable: $($uri.Host)"
    } catch {
        Write-Warn "Could not reach host - may be VPN or proxy. Continuing anyway."
    }

    Write-Step "Execution policy"
    $policy = Get-ExecutionPolicy
    if ($policy -in @("Unrestricted","RemoteSigned","Bypass")) {
        Write-OK "Execution policy: $policy"
    } else {
        Write-Warn "Execution policy is '$policy'. Fix: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
    }

    return $pass
}

# ============================================================
# LIST PROVISIONING
# ============================================================
function New-AssetList {
    param(
        [string]$ListName,
        [array] $Cols
    )
    Write-Step "Provisioning list: $ListName"

    $existing = Get-PnPList -Identity $ListName -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        if ($PSCmdlet.ShouldProcess($ListName, "Create SharePoint list")) {
            New-PnPList -Title $ListName -Template GenericList -OnQuickLaunch:$false | Out-Null
            Write-OK "List created: $ListName"
        }
    } else {
        Write-Warn "List already exists (columns will be checked): $ListName"
    }

    foreach ($col in $Cols) {
        $ec = Get-PnPField -List $ListName -Identity $col.Name -ErrorAction SilentlyContinue
        if ($null -ne $ec) { continue }
        try {
            if ($col.Type -eq "Choice") {
                $choices = ($col.Choices | ForEach-Object { "<CHOICE>$_</CHOICE>" }) -join ""
                $xml = "<Field Type='Choice' Name='$($col.Name)' DisplayName='$($col.Name)'" +
                       " Required='$(if($col.Required){"TRUE"}else{"FALSE"})'>" +
                       "<Default>$($col.Default)</Default>" +
                       "<CHOICES>$choices</CHOICES></Field>"
                Add-PnPFieldFromXml -List $ListName -FieldXml $xml | Out-Null
            } elseif ($col.Type -eq "Note") {
                Add-PnPField -List $ListName -DisplayName $col.Name -InternalName $col.Name -Type Note -Required:$col.Required | Out-Null
            } elseif ($col.Type -eq "DateTime") {
                Add-PnPField -List $ListName -DisplayName $col.Name -InternalName $col.Name -Type DateTime -Required:$col.Required | Out-Null
            } elseif ($col.Type -eq "Number") {
                Add-PnPField -List $ListName -DisplayName $col.Name -InternalName $col.Name -Type Number -Required:$col.Required | Out-Null
            } elseif ($col.Type -eq "Boolean") {
                Add-PnPField -List $ListName -DisplayName $col.Name -InternalName $col.Name -Type Boolean -Required:$col.Required | Out-Null
            } elseif ($col.Type -eq "Currency") {
                Add-PnPField -List $ListName -DisplayName $col.Name -InternalName $col.Name -Type Currency -Required:$col.Required | Out-Null
            } elseif ($col.Type -eq "User") {
                $xml = "<Field Type='User' Name='$($col.Name)' DisplayName='$($col.Name)'" +
                       " Required='$(if($col.Required){"TRUE"}else{"FALSE"})'" +
                       " UserSelectionMode='PeopleOnly' UserSelectionScope='0'/>"
                Add-PnPFieldFromXml -List $ListName -FieldXml $xml | Out-Null
            } else {
                Add-PnPField -List $ListName -DisplayName $col.Name -InternalName $col.Name -Type Text -Required:$col.Required | Out-Null
            }
            Write-OK "  Column added: $($col.Name)"
        } catch {
            Write-Warn "  Column issue ($($col.Name)): $($_.Exception.Message)"
        }
    }
}

# ============================================================
# VIEW UPDATE FUNCTION
# Updates the default All Items view to show all list columns
# ============================================================
function Update-DefaultView {
    param(
        [string]$ListName,
        [string[]]$Fields
    )
    Write-Step "Updating default view: $ListName"
    try {
        $view = Get-PnPView -List $ListName -Identity "All Items" -ErrorAction SilentlyContinue
        if ($null -eq $view) {
            $view = Get-PnPView -List $ListName | Select-Object -First 1
        }
        if ($null -ne $view) {
            Set-PnPView -List $ListName -Identity $view.Title -Fields $Fields | Out-Null
            Write-OK "  View updated: $($view.Title) -> $($Fields.Count) columns"
        } else {
            Write-Warn "  No view found for $ListName"
        }
    } catch {
        Write-Warn "  View update issue ($ListName): $($_.Exception.Message)"
    }
}

# ============================================================
# IMPORT FUNCTION
# ============================================================
function Import-AssetItems {
    param([string]$ListName, [array]$Items)

    Write-Step "Importing $($Items.Count) items -> $ListName"
    $added=0; $skipped=0; $failed=0; $i=0
    $total = $Items.Count

    $existing = @()
    try {
        $existing = Get-PnPListItem -List $ListName -PageSize 500 -Fields "Title" |
                    ForEach-Object { $_.FieldValues["Title"] }
    } catch { }

    foreach ($item in $Items) {
        $i++
        $pct   = [int](($i / $total) * 100)
        $short = if ($item.Title.Length -gt 55) { $item.Title.Substring(0,55) + "..." } else { $item.Title }
        Write-Progress -Activity "Importing $ListName" -Status "$i/$total - $short" -PercentComplete $pct

        if ($existing -contains $item.Title) { $skipped++; continue }

        if ($PSCmdlet.ShouldProcess($item.Title, "Add to $ListName")) {
            try {
                $values = @{}
                foreach ($prop in $item.PSObject.Properties) {
                    if ($prop.Name -eq "Title") { continue }
                    if ($null -ne $prop.Value -and $prop.Value -ne "") {
                        $values[$prop.Name] = $prop.Value
                    }
                }
                Add-PnPListItem -List $ListName -Values (@{ Title = $item.Title } + $values) | Out-Null
                Write-Host "     Inserted: $short" -ForegroundColor Green
                $added++
            } catch {
                $short2 = if ($item.Title.Length -gt 40) { $item.Title.Substring(0,40) } else { $item.Title }
                Write-Fail "FAILED: $short2 -> $($_.Exception.Message)"
                $failed++
            }
        }
    }

    Write-Progress -Activity "Importing $ListName" -Completed
    Write-OK "Done: Added=$added  Skipped=$skipped  Failed=$failed"
    return @{ Added=$added; Skipped=$skipped; Failed=$failed }
}

# ============================================================
# LIST SCHEMAS
# ============================================================

$Cols_AppAdmins = @(
    @{ Name="UserEmail";    Type="Text";    Required=$true;  Default=""; Choices=@() }
    @{ Name="DisplayName";  Type="Text";    Required=$false; Default=""; Choices=@() }
    @{ Name="Role";         Type="Choice";  Required=$true;  Default="IT Admin"
       Choices=@("IT Admin","Super Admin","Read-Only Admin") }
    @{ Name="IsActive";     Type="Boolean"; Required=$false; Default=""; Choices=@() }
    @{ Name="Department";   Type="Text";    Required=$false; Default=""; Choices=@() }
)

$Cols_AssetCatalogue = @(
    @{ Name="Category";     Type="Choice";  Required=$true;  Default="Laptop"
       Choices=@("Laptop","Desktop","Monitor","Keyboard","Mouse","Headset","Docking Station","Mobile Phone","Tablet","Other") }
    @{ Name="Description";  Type="Note";    Required=$false; Default=""; Choices=@() }
    @{ Name="StockQty";     Type="Number";  Required=$true;  Default=""; Choices=@() }
    @{ Name="Status";       Type="Choice";  Required=$true;  Default="Active"
       Choices=@("Active","Out of Stock","Retired") }
    @{ Name="AvgLifeYears"; Type="Number";  Required=$false; Default=""; Choices=@() }
    @{ Name="UnitCost";     Type="Currency";Required=$false; Default=""; Choices=@() }
)

$Cols_AssetRequests = @(
    @{ Name="RequestedByEmail"; Type="Text";     Required=$true;  Default=""; Choices=@() }
    @{ Name="AssetType";        Type="Text";     Required=$true;  Default=""; Choices=@() }
    @{ Name="AssetCategory";    Type="Choice";   Required=$false; Default="Laptop"
       Choices=@("Laptop","Desktop","Monitor","Keyboard","Mouse","Headset","Docking Station","Mobile Phone","Tablet","Other") }
    @{ Name="Quantity";         Type="Number";   Required=$true;  Default=""; Choices=@() }
    @{ Name="Justification";    Type="Note";     Required=$true;  Default=""; Choices=@() }
    @{ Name="Urgency";          Type="Choice";   Required=$true;  Default="Medium"
       Choices=@("Low","Medium","High","Critical") }
    @{ Name="Status";           Type="Choice";   Required=$true;  Default="Pending"
       Choices=@("Pending","Approved","Denied","Cancelled") }
    @{ Name="ApprovedByEmail";  Type="Text";     Required=$false; Default=""; Choices=@() }
    @{ Name="ITNotes";          Type="Note";     Required=$false; Default=""; Choices=@() }
    @{ Name="NeededByDate";     Type="DateTime"; Required=$false; Default=""; Choices=@() }
    @{ Name="ExpectedDelivery"; Type="DateTime"; Required=$false; Default=""; Choices=@() }
    @{ Name="SubmittedDate";    Type="DateTime"; Required=$true;  Default=""; Choices=@() }
    @{ Name="DelegatedTo";      Type="Text";     Required=$false; Default=""; Choices=@() }
)

$Cols_AssetAssignments = @(
    @{ Name="AssetName";        Type="Text";     Required=$true;  Default=""; Choices=@() }
    @{ Name="AssetCategory";    Type="Choice";   Required=$false; Default="Laptop"
       Choices=@("Laptop","Desktop","Monitor","Keyboard","Mouse","Headset","Docking Station","Mobile Phone","Tablet","Other") }
    @{ Name="AssignedToEmail";  Type="Text";     Required=$true;  Default=""; Choices=@() }
    @{ Name="SerialNumber";     Type="Text";     Required=$false; Default=""; Choices=@() }
    @{ Name="AssetTag";         Type="Text";     Required=$false; Default=""; Choices=@() }
    @{ Name="AssignedDate";     Type="DateTime"; Required=$true;  Default=""; Choices=@() }
    @{ Name="Status";           Type="Choice";   Required=$true;  Default="Active"
       Choices=@("Active","Returned","Lost","Damaged") }
    @{ Name="WarrantyExpiry";   Type="DateTime"; Required=$false; Default=""; Choices=@() }
    @{ Name="SourceRequestID";  Type="Text";     Required=$false; Default=""; Choices=@() }
    @{ Name="LastAttestedDate"; Type="DateTime"; Required=$false; Default=""; Choices=@() }
    @{ Name="AttestedThisCycle";Type="Boolean";  Required=$false; Default=""; Choices=@() }
    @{ Name="Notes";            Type="Note";     Required=$false; Default=""; Choices=@() }
)

$Cols_Attestations = @(
    @{ Name="AssignmentID";  Type="Text";     Required=$true;  Default=""; Choices=@() }
    @{ Name="AttestByEmail"; Type="Text";     Required=$true;  Default=""; Choices=@() }
    @{ Name="AttestDate";    Type="DateTime"; Required=$true;  Default=""; Choices=@() }
    @{ Name="Confirmed";     Type="Boolean";  Required=$false; Default=""; Choices=@() }
    @{ Name="Condition";     Type="Choice";   Required=$true;  Default="Good"
       Choices=@("Good","Minor Wear","Damaged","Missing","Lost") }
    @{ Name="Comments";      Type="Note";     Required=$false; Default=""; Choices=@() }
    @{ Name="CycleYear";     Type="Text";     Required=$true;  Default=""; Choices=@() }
    @{ Name="ITReviewed";    Type="Boolean";  Required=$false; Default=""; Choices=@() }
    @{ Name="ITComment";     Type="Note";     Required=$false; Default=""; Choices=@() }
)

$Cols_Notifications = @(
    @{ Name="RecipientEmail"; Type="Text";     Required=$true;  Default=""; Choices=@() }
    @{ Name="Message";        Type="Note";     Required=$true;  Default=""; Choices=@() }
    @{ Name="NotifType";      Type="Choice";   Required=$true;  Default="Request"
       Choices=@("Request","Assignment","Attestation","Announcement") }
    @{ Name="IsRead";         Type="Boolean";  Required=$false; Default=""; Choices=@() }
    @{ Name="CreatedDate";    Type="DateTime"; Required=$true;  Default=""; Choices=@() }
    @{ Name="RelatedItemID";  Type="Text";     Required=$false; Default=""; Choices=@() }
)

# ============================================================
# TEST DATA — AppAdmins
# ============================================================
$Data_AppAdmins = @(
    [PSCustomObject]@{ Title="Demo WR";           UserEmail=$U_SuperAdmin; DisplayName="Demo WR";           Role="Super Admin";    IsActive=$true; Department="IT" }
    [PSCustomObject]@{ Title="HeapDesk ReadOnly";  UserEmail=$U_ITAdmin;   DisplayName="HeapDesk ReadOnly";  Role="IT Admin";       IsActive=$true; Department="IT" }
    [PSCustomObject]@{ Title="Helpdesk Team";      UserEmail=$U_ReadOnly;  DisplayName="Helpdesk Team";      Role="Read-Only Admin"; IsActive=$true; Department="IT" }
)

# ============================================================
# TEST DATA — AssetCatalogue (10 items = Total Assets KPI)
# ============================================================
$Data_AssetCatalogue = @(
    [PSCustomObject]@{ Title="Dell Latitude 5540";   Category="Laptop";          Description="Intel i7 16GB RAM 512GB SSD";     StockQty=8;  Status="Active";       AvgLifeYears=4; UnitCost=1800 }
    [PSCustomObject]@{ Title="HP EliteDesk 800 G9";  Category="Desktop";         Description="Intel i5 8GB RAM 256GB SSD";      StockQty=5;  Status="Active";       AvgLifeYears=5; UnitCost=1200 }
    [PSCustomObject]@{ Title="Dell 27 Inch Monitor";  Category="Monitor";         Description="4K IPS USB-C 27 inch";            StockQty=12; Status="Active";       AvgLifeYears=5; UnitCost=450  }
    [PSCustomObject]@{ Title="Logitech MX Keys";      Category="Keyboard";        Description="Wireless backlit keyboard";        StockQty=18; Status="Active";       AvgLifeYears=3; UnitCost=120  }
    [PSCustomObject]@{ Title="Logitech MX Master 3";  Category="Mouse";           Description="Wireless ergonomic mouse";         StockQty=15; Status="Active";       AvgLifeYears=3; UnitCost=100  }
    [PSCustomObject]@{ Title="Jabra Evolve2 55";      Category="Headset";         Description="Wireless ANC MS Teams certified";  StockQty=0;  Status="Out of Stock"; AvgLifeYears=3; UnitCost=350  }
    [PSCustomObject]@{ Title="Dell WD19S Dock";       Category="Docking Station"; Description="130W USB-C dual display";         StockQty=4;  Status="Active";       AvgLifeYears=4; UnitCost=280  }
    [PSCustomObject]@{ Title="iPhone 14";             Category="Mobile Phone";    Description="128GB corporate MDM enrolled";    StockQty=3;  Status="Active";       AvgLifeYears=3; UnitCost=1200 }
    [PSCustomObject]@{ Title="iPad Air";              Category="Tablet";          Description="64GB WiFi with keyboard cover";   StockQty=2;  Status="Active";       AvgLifeYears=4; UnitCost=950  }
    [PSCustomObject]@{ Title="Plantronics C720";      Category="Headset";         Description="USB wired noise cancelling";       StockQty=0;  Status="Out of Stock"; AvgLifeYears=3; UnitCost=180  }
)

# ============================================================
# TEST DATA — AssetRequests
# 5 Pending, 2 Approved June 2026, 1 Denied, 1 Cancelled
# Dashboard: Pending=5, Approved This Month=2
# ============================================================
$Data_AssetRequests = @(
    [PSCustomObject]@{
        Title="REQ-20260601-001"; RequestedByEmail=$U_User1; AssetType="Dell Latitude 5540"; AssetCategory="Laptop"
        Quantity=1; Justification="New hire joining IT department requires laptop for day-to-day work"
        Urgency="High"; Status="Approved"; ApprovedByEmail=$U_SuperAdmin
        ITNotes="Approved. Device will be ready by 10 June."; SubmittedDate="2026-06-01"; ExpectedDelivery="2026-06-10"
    }
    [PSCustomObject]@{
        Title="REQ-20260602-002"; RequestedByEmail=$U_User2; AssetType="Dell 27 Inch Monitor"; AssetCategory="Monitor"
        Quantity=1; Justification="Current monitor is over 7 years old and causing eye strain"
        Urgency="Medium"; Status="Pending"; SubmittedDate="2026-06-02"
    }
    [PSCustomObject]@{
        Title="REQ-20260603-003"; RequestedByEmail=$U_User1; AssetType="Jabra Evolve2 55"; AssetCategory="Headset"
        Quantity=1; Justification="Required for remote calls as part of customer support role"
        Urgency="Critical"; Status="Denied"; ApprovedByEmail=$U_SuperAdmin
        ITNotes="Item out of stock. Please re-submit in 2 weeks."; SubmittedDate="2026-06-03"
    }
    [PSCustomObject]@{
        Title="REQ-20260604-004"; RequestedByEmail=$U_User3; AssetType="Logitech MX Master 3"; AssetCategory="Mouse"
        Quantity=1; Justification="Old mouse scroll wheel failure is affecting daily productivity"
        Urgency="Medium"; Status="Pending"; SubmittedDate="2026-06-04"
    }
    [PSCustomObject]@{
        Title="REQ-20260605-005"; RequestedByEmail=$U_User4; AssetType="Dell WD19S Dock"; AssetCategory="Docking Station"
        Quantity=1; Justification="Hot desk setup requires docking station for dual monitor connectivity"
        Urgency="Low"; Status="Pending"; SubmittedDate="2026-06-05"
    }
    [PSCustomObject]@{
        Title="REQ-20260606-006"; RequestedByEmail=$U_User2; AssetType="iPhone 14"; AssetCategory="Mobile Phone"
        Quantity=1; Justification="Replacement for damaged device used by field operations staff"
        Urgency="Critical"; Status="Pending"; SubmittedDate="2026-06-06"
    }
    [PSCustomObject]@{
        Title="REQ-20260607-007"; RequestedByEmail=$U_User5; AssetType="iPad Air"; AssetCategory="Tablet"
        Quantity=1; Justification="Field visits require mobile device for on-site data entry"
        Urgency="High"; Status="Approved"; ApprovedByEmail=$U_SuperAdmin
        ITNotes="Approved. Collect from IT room 3B."; SubmittedDate="2026-06-07"; ExpectedDelivery="2026-06-09"
    }
    [PSCustomObject]@{
        Title="REQ-20260608-008"; RequestedByEmail=$U_User3; AssetType="HP EliteDesk 800 G9"; AssetCategory="Desktop"
        Quantity=1; Justification="Finance workstation replacement due to hardware failure last week"
        Urgency="High"; Status="Pending"; SubmittedDate="2026-06-08"
    }
    [PSCustomObject]@{
        Title="REQ-20260609-009"; RequestedByEmail=$U_User4; AssetType="Logitech MX Keys"; AssetCategory="Keyboard"
        Quantity=1; Justification="Ergonomic keyboard needed due to RSI assessment recommendation"
        Urgency="Low"; Status="Cancelled"; SubmittedDate="2026-06-09"
        ITNotes="Cancelled by requester - resolved with existing equipment"
    }
)

# ============================================================
# TEST DATA — AssetAssignments
# 7 Active: 5 with AttestedThisCycle=false = Overdue KPI = 5
# 1 Returned: excluded from Overdue count
# ============================================================
$Data_AssetAssignments = @(
    [PSCustomObject]@{
        Title="ASGN-2026-0001"; AssetName="Dell Latitude 5540"; AssetCategory="Laptop"
        AssignedToEmail=$U_User1; SerialNumber="SN-DL5540-00112"; AssetTag="IT-ASSET-0042"
        AssignedDate="2026-06-09"; Status="Active"; WarrantyExpiry="2029-06-09"
        SourceRequestID="REQ-20260601-001"; AttestedThisCycle=$false
    }
    [PSCustomObject]@{
        Title="ASGN-2026-0002"; AssetName="Logitech MX Master 3"; AssetCategory="Mouse"
        AssignedToEmail=$U_User1; SerialNumber="SN-LOGI-00891"; AssetTag="IT-ASSET-0031"
        AssignedDate="2026-03-15"; Status="Active"; WarrantyExpiry="2029-03-15"
        LastAttestedDate="2026-04-01"; AttestedThisCycle=$true
    }
    [PSCustomObject]@{
        Title="ASGN-2026-0003"; AssetName="HP EliteDesk 800 G9"; AssetCategory="Desktop"
        AssignedToEmail=$U_User2; SerialNumber="SN-HP800-00055"; AssetTag="IT-ASSET-0018"
        AssignedDate="2025-11-20"; Status="Active"; WarrantyExpiry="2028-11-20"
        LastAttestedDate="2026-04-01"; AttestedThisCycle=$true
    }
    [PSCustomObject]@{
        Title="ASGN-2026-0004"; AssetName="Dell 27 Inch Monitor"; AssetCategory="Monitor"
        AssignedToEmail=$U_User2; SerialNumber="SN-MON-00234"; AssetTag="IT-ASSET-0055"
        AssignedDate="2024-08-10"; Status="Active"; WarrantyExpiry="2029-08-10"
        AttestedThisCycle=$false
    }
    [PSCustomObject]@{
        Title="ASGN-2026-0005"; AssetName="Jabra Evolve2 55"; AssetCategory="Headset"
        AssignedToEmail=$U_User3; SerialNumber="SN-JAB-00076"; AssetTag="IT-ASSET-0063"
        AssignedDate="2025-03-22"; Status="Active"; WarrantyExpiry="2028-03-22"
        AttestedThisCycle=$false
    }
    [PSCustomObject]@{
        Title="ASGN-2026-0006"; AssetName="iPad Air"; AssetCategory="Tablet"
        AssignedToEmail=$U_User5; SerialNumber="SN-TAB-00021"; AssetTag="IT-ASSET-0071"
        AssignedDate="2026-06-07"; Status="Active"; WarrantyExpiry="2030-06-07"
        SourceRequestID="REQ-20260607-007"; AttestedThisCycle=$false
    }
    [PSCustomObject]@{
        Title="ASGN-2026-0007"; AssetName="Logitech MX Keys"; AssetCategory="Keyboard"
        AssignedToEmail=$U_User4; SerialNumber="SN-KEY-00045"; AssetTag="IT-ASSET-0082"
        AssignedDate="2026-01-10"; Status="Active"; WarrantyExpiry="2029-01-10"
        AttestedThisCycle=$false
    }
    [PSCustomObject]@{
        Title="ASGN-2026-0008"; AssetName="Dell WD19S Dock"; AssetCategory="Docking Station"
        AssignedToEmail=$U_User3; SerialNumber="SN-DCK-00033"; AssetTag="IT-ASSET-0091"
        AssignedDate="2025-07-05"; Status="Returned"; WarrantyExpiry="2029-07-05"
        AttestedThisCycle=$false; Notes="Returned after role change to remote-only"
    }
)

# ============================================================
# TEST DATA — Attestations
# ============================================================
$Data_Attestations = @(
    [PSCustomObject]@{
        Title="ATT-2026-Q2-0001"; AssignmentID="ASGN-2026-0002"; AttestByEmail=$U_User1
        AttestDate="2026-04-01"; Confirmed=$true; Condition="Good"; CycleYear="2026-Q2"; ITReviewed=$false
    }
    [PSCustomObject]@{
        Title="ATT-2026-Q2-0002"; AssignmentID="ASGN-2026-0003"; AttestByEmail=$U_User2
        AttestDate="2026-04-01"; Confirmed=$true; Condition="Minor Wear"
        Comments="Small scratch on top panel, otherwise fully functional"; CycleYear="2026-Q2"; ITReviewed=$false
    }
    [PSCustomObject]@{
        Title="ATT-2026-Q2-0003"; AssignmentID="ASGN-2026-0005"; AttestByEmail=$U_User3
        AttestDate="2026-04-03"; Confirmed=$false; Condition="Missing"
        Comments="Device not found after office move. Checking with facilities team."; CycleYear="2026-Q2"; ITReviewed=$false
    }
    [PSCustomObject]@{
        Title="ATT-2026-Q1-0001"; AssignmentID="ASGN-2026-0002"; AttestByEmail=$U_User1
        AttestDate="2026-01-03"; Confirmed=$true; Condition="Good"; CycleYear="2026-Q1"; ITReviewed=$true
        ITComment="Reviewed and confirmed by IT. No issues."
    }
    [PSCustomObject]@{
        Title="ATT-2026-Q1-0002"; AssignmentID="ASGN-2026-0003"; AttestByEmail=$U_User2
        AttestDate="2026-01-05"; Confirmed=$true; Condition="Good"; CycleYear="2026-Q1"; ITReviewed=$true
        ITComment="Reviewed and confirmed by IT. No issues."
    }
    [PSCustomObject]@{
        Title="ATT-2026-Q1-0003"; AssignmentID="ASGN-2026-0004"; AttestByEmail=$U_User2
        AttestDate="2026-01-06"; Confirmed=$true; Condition="Minor Wear"
        Comments="Monitor has dead pixel in bottom-right corner - low impact"; CycleYear="2026-Q1"; ITReviewed=$false
    }
)

# ============================================================
# TEST DATA — Notifications (all 4 types, read and unread)
# ============================================================
$Data_Notifications = @(
    [PSCustomObject]@{
        Title="Request Approved"; RecipientEmail=$U_User1
        Message="Your request REQ-20260601-001 for Dell Latitude 5540 has been approved. Expected delivery 10 June 2026."
        NotifType="Request"; IsRead=$false; CreatedDate="2026-06-02"; RelatedItemID="REQ-20260601-001"
    }
    [PSCustomObject]@{
        Title="Asset Assigned Dell Latitude 5540"; RecipientEmail=$U_User1
        Message="Your asset Dell Latitude 5540 (Serial: SN-DL5540-00112, Tag: IT-ASSET-0042) has been assigned. Collect from IT room 3B on 9 June 2026."
        NotifType="Assignment"; IsRead=$false; CreatedDate="2026-06-09"; RelatedItemID="ASGN-2026-0001"
    }
    [PSCustomObject]@{
        Title="Request Denied"; RecipientEmail=$U_User1
        Message="Your request REQ-20260603-003 for Jabra Evolve2 55 has been denied. Item out of stock. Please re-submit in 2 weeks."
        NotifType="Request"; IsRead=$true; CreatedDate="2026-06-03"; RelatedItemID="REQ-20260603-003"
    }
    [PSCustomObject]@{
        Title="Attestation Reminder 2026-Q2"; RecipientEmail=$U_User1
        Message="Action required: Please attest your assigned assets for the 2026-Q2 cycle. Open the IT Asset Management app and go to Attest My Assets."
        NotifType="Attestation"; IsRead=$true; CreatedDate="2026-04-01"
    }
    [PSCustomObject]@{
        Title="Request Submitted"; RecipientEmail=$U_User2
        Message="Your request REQ-20260602-002 for Dell 27 Inch Monitor has been submitted and is pending IT approval."
        NotifType="Request"; IsRead=$true; CreatedDate="2026-06-02"; RelatedItemID="REQ-20260602-002"
    }
    [PSCustomObject]@{
        Title="Request Pending Review"; RecipientEmail=$U_User2
        Message="Your request REQ-20260606-006 for iPhone 14 has been submitted. IT will review within 2 business days."
        NotifType="Request"; IsRead=$false; CreatedDate="2026-06-06"; RelatedItemID="REQ-20260606-006"
    }
    [PSCustomObject]@{
        Title="Attestation Reminder 2026-Q2"; RecipientEmail=$U_User2
        Message="Action required: Please attest your assigned assets for the 2026-Q2 cycle. Open the IT Asset Management app and go to Attest My Assets."
        NotifType="Attestation"; IsRead=$false; CreatedDate="2026-04-01"
    }
    [PSCustomObject]@{
        Title="Attestation Reminder 2026-Q2"; RecipientEmail=$U_User3
        Message="Action required: Please attest your assigned assets for the 2026-Q2 cycle. Open the IT Asset Management app and go to Attest My Assets."
        NotifType="Attestation"; IsRead=$false; CreatedDate="2026-04-01"
    }
    [PSCustomObject]@{
        Title="Missing Asset Flagged"; RecipientEmail=$U_SuperAdmin
        Message="URGENT: Asset Jabra Evolve2 55 (ASGN-2026-0005) assigned to user3 flagged as Missing during Q2 attestation. IT investigation required."
        NotifType="Attestation"; IsRead=$false; CreatedDate="2026-04-03"; RelatedItemID="ASGN-2026-0005"
    }
    [PSCustomObject]@{
        Title="Request Submitted"; RecipientEmail=$U_User3
        Message="Your request REQ-20260604-004 for Logitech MX Master 3 has been submitted and is pending IT approval."
        NotifType="Request"; IsRead=$true; CreatedDate="2026-06-04"; RelatedItemID="REQ-20260604-004"
    }
    [PSCustomObject]@{
        Title="Request Submitted"; RecipientEmail=$U_User4
        Message="Your request REQ-20260605-005 for Dell WD19S Dock has been submitted and is pending IT approval."
        NotifType="Request"; IsRead=$false; CreatedDate="2026-06-05"; RelatedItemID="REQ-20260605-005"
    }
    [PSCustomObject]@{
        Title="Attestation Reminder 2026-Q2"; RecipientEmail=$U_User4
        Message="Action required: Please attest your assigned assets for the 2026-Q2 cycle. Open the IT Asset Management app and go to Attest My Assets."
        NotifType="Attestation"; IsRead=$false; CreatedDate="2026-04-01"
    }
    [PSCustomObject]@{
        Title="Request Approved"; RecipientEmail=$U_User5
        Message="Your request REQ-20260607-007 for iPad Air has been approved. Please collect from IT helpdesk on 9 June 2026."
        NotifType="Request"; IsRead=$false; CreatedDate="2026-06-07"; RelatedItemID="REQ-20260607-007"
    }
    [PSCustomObject]@{
        Title="Asset Assigned iPad Air"; RecipientEmail=$U_User5
        Message="Your asset iPad Air (Serial: SN-TAB-00021, Tag: IT-ASSET-0071) has been assigned. Collect from IT helpdesk with your staff ID."
        NotifType="Assignment"; IsRead=$false; CreatedDate="2026-06-08"; RelatedItemID="ASGN-2026-0006"
    }
    [PSCustomObject]@{
        Title="Attestation Reminder 2026-Q2"; RecipientEmail=$U_User5
        Message="Action required: Please attest your assigned assets for the 2026-Q2 cycle. Open the IT Asset Management app and go to Attest My Assets."
        NotifType="Attestation"; IsRead=$false; CreatedDate="2026-04-01"
    }
    [PSCustomObject]@{
        Title="Quarterly IT Announcement"; RecipientEmail=$U_User1
        Message="IT reminder: Q2 asset attestation cycle closes 30 June 2026. All staff must confirm assigned assets. Contact IT helpdesk for any issues."
        NotifType="Announcement"; IsRead=$false; CreatedDate="2026-06-01"
    }
    [PSCustomObject]@{
        Title="Quarterly IT Announcement"; RecipientEmail=$U_User2
        Message="IT reminder: Q2 asset attestation cycle closes 30 June 2026. All staff must confirm assigned assets. Contact IT helpdesk for any issues."
        NotifType="Announcement"; IsRead=$false; CreatedDate="2026-06-01"
    }
    [PSCustomObject]@{
        Title="Quarterly IT Announcement"; RecipientEmail=$U_User3
        Message="IT reminder: Q2 asset attestation cycle closes 30 June 2026. All staff must confirm assigned assets. Contact IT helpdesk for any issues."
        NotifType="Announcement"; IsRead=$false; CreatedDate="2026-06-01"
    }
)

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Banner "IT Asset Management — List Provisioning v$ScriptVersion"
Write-Host "  Site    : $SiteUrl"  -ForegroundColor White
Write-Host "  WhatIf  : $($WhatIfPreference)" -ForegroundColor White
Write-Host "  Started : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White

# ---------- Pre-flight ----------
$preflightOk = Invoke-PreflightChecks -Url $SiteUrl
if (-not $preflightOk) {
    Write-Host ""
    Write-Fail "One or more pre-flight checks failed. Fix the issues above and re-run."
    exit 1
}

Write-Host ""
Write-Host "  Pre-flight passed. Proceeding with deployment..." -ForegroundColor Green

# ---------- Connect ----------
Write-Banner "Connecting to SharePoint"
try {
    Connect-PnPOnline -Url $SiteUrl -UseWebLogin
    Write-OK "Connected to: $SiteUrl"
    try {
        $siteInfo = Get-PnPSite -Includes Title
        Write-OK "Site title  : $($siteInfo.Title)"
    } catch {
        Write-OK "Connected successfully (site title unavailable)"
    }
} catch {
    Write-Fail "Connection failed: $($_.Exception.Message)"
    exit 1
}

# ---------- Provision Lists ----------
Write-Banner "Provisioning Lists"

try { New-AssetList -ListName "AppAdmins"       -Cols $Cols_AppAdmins        } catch { Write-Fail "AppAdmins: $_"        }
try { New-AssetList -ListName "AssetCatalogue"   -Cols $Cols_AssetCatalogue   } catch { Write-Fail "AssetCatalogue: $_"   }
try { New-AssetList -ListName "AssetRequests"    -Cols $Cols_AssetRequests    } catch { Write-Fail "AssetRequests: $_"    }
try { New-AssetList -ListName "AssetAssignments" -Cols $Cols_AssetAssignments } catch { Write-Fail "AssetAssignments: $_" }
try { New-AssetList -ListName "Attestations"     -Cols $Cols_Attestations     } catch { Write-Fail "Attestations: $_"     }
try { New-AssetList -ListName "Notifications"    -Cols $Cols_Notifications    } catch { Write-Fail "Notifications: $_"    }

# ---------- Update Default Views ----------
Write-Banner "Updating Default Views"

Update-DefaultView -ListName "AppAdmins" -Fields @(
    "Title","UserEmail","DisplayName","Role","IsActive","Department"
)

Update-DefaultView -ListName "AssetCatalogue" -Fields @(
    "Title","Category","Description","StockQty","Status","AvgLifeYears","UnitCost"
)

Update-DefaultView -ListName "AssetRequests" -Fields @(
    "Title","RequestedByEmail","AssetType","AssetCategory","Quantity",
    "Urgency","Status","ApprovedByEmail","ITNotes","SubmittedDate","ExpectedDelivery"
)

Update-DefaultView -ListName "AssetAssignments" -Fields @(
    "Title","AssetName","AssetCategory","AssignedToEmail","SerialNumber",
    "AssetTag","AssignedDate","Status","WarrantyExpiry","SourceRequestID",
    "LastAttestedDate","AttestedThisCycle"
)

Update-DefaultView -ListName "Attestations" -Fields @(
    "Title","AssignmentID","AttestByEmail","AttestDate","Confirmed",
    "Condition","Comments","CycleYear","ITReviewed","ITComment"
)

Update-DefaultView -ListName "Notifications" -Fields @(
    "Title","RecipientEmail","Message","NotifType","IsRead","CreatedDate","RelatedItemID"
)

# ---------- Import Data ----------
Write-Banner "Importing Test Data"

$totalAdded=0; $totalSkipped=0; $totalFailed=0

$importJobs = @(
    @{ List="AppAdmins";        Data=$Data_AppAdmins        }
    @{ List="AssetCatalogue";   Data=$Data_AssetCatalogue   }
    @{ List="AssetRequests";    Data=$Data_AssetRequests    }
    @{ List="AssetAssignments"; Data=$Data_AssetAssignments }
    @{ List="Attestations";     Data=$Data_Attestations     }
    @{ List="Notifications";    Data=$Data_Notifications    }
)

foreach ($job in $importJobs) {
    try {
        $result = Import-AssetItems -ListName $job.List -Items $job.Data
        $totalAdded   += $result.Added
        $totalSkipped += $result.Skipped
        $totalFailed  += $result.Failed
    } catch {
        Write-Fail "Import error for $($job.List): $($_.Exception.Message)"
    }
}

# ---------- Disconnect ----------
try { Disconnect-PnPOnline; Write-OK "Disconnected cleanly" } catch { }

# ---------- Summary ----------
Write-Banner "Deployment Summary"

foreach ($job in $importJobs) {
    Write-Host ("  {0,-25} {1} items" -f $job.List, $job.Data.Count) -ForegroundColor White
}

Write-Host ""
Write-Host "  Total added   : $totalAdded"   -ForegroundColor Green
Write-Host "  Total skipped : $totalSkipped" -ForegroundColor Yellow
Write-Host "  Total failed  : $totalFailed"  -ForegroundColor $(if($totalFailed -gt 0){"Red"}else{"Green"})
Write-Host ""
Write-Host "  Expected dashboard KPI values:" -ForegroundColor Cyan
Write-Host "    Total Assets        : 10" -ForegroundColor White
Write-Host "    Pending Requests    : 5  (REQ-002,004,005,006,008)" -ForegroundColor White
Write-Host "    Approved This Month : 2  (REQ-001,007 - June 2026)" -ForegroundColor White
Write-Host "    Overdue Attestation : 5  (ASGN-001,004,005,006,007)" -ForegroundColor White
Write-Host ""
Write-Host "  NOTE: Person columns (RequestedBy, ApprovedBy, AssignedTo," -ForegroundColor Yellow
Write-Host "  AttestBy) must be filled manually in each list after import." -ForegroundColor Yellow
Write-Host "  Open each list, Edit in grid view, click each Person cell." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open $SiteUrl and verify all 6 lists" -ForegroundColor White
Write-Host "  2. Fill Person columns manually in each list" -ForegroundColor White
Write-Host "  3. Power Apps: Data panel -> refresh all 6 lists" -ForegroundColor White
Write-Host "  4. Tree View -> App -> Run OnStart" -ForegroundColor White
Write-Host "  5. Press F5 and verify dashboard KPIs" -ForegroundColor White
Write-Host ""
Write-Host "  Finished at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host ""