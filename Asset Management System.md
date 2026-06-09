# IT Asset Request & Management App — Summary Reference

**Power Apps Canvas App · SharePoint Online · Power Automate**

**Author:** Vishnu WR — Microsoft Solution Architect
**Email:** info@wrvishnu.com | **Web:** www.wrvishnu.com

---

## Overview

A full-featured IT Asset Request and Management system built on Power Apps Canvas App (Tablet 1366×768), SharePoint Online, and Power Automate. Staff submit asset requests, IT admins approve and assign assets, and users attest asset possession quarterly.

---

## App Flow Diagram

![IT Asset Management — App Flow Overview](../assets/app-flow-overview.png)

*End-to-end flow: Staff submits request → IT admin approves → Asset assigned → User attests quarterly*

---

## Architecture

| Layer      | Technology                     | Purpose                             |
| ---------- | ------------------------------ | ----------------------------------- |
| App        | Power Apps Canvas App (Tablet) | All UI and business logic           |
| Data       | SharePoint Online — 6 lists    | All data storage                    |
| Automation | Power Automate — 4 flows       | Approvals, notifications, reminders |
| Auth       | AppAdmins SPO list             | Role-based access control           |

---

## SharePoint Lists

> **Do not create lists manually.** Use the schema files or PowerShell script located in the GitHub folder **`SPO-Schema`**.
>
> - **JSON schema files** — one per list, use with SharePoint site script or PnP provisioning
> - **PowerShell script** — `Deploy-ITAssetManagement.ps1` — creates all 6 lists, sets columns, loads test data in one run. Requires PnP.PowerShell v1.12.0.
>
> Verify all 6 lists exist in SharePoint before opening Power Apps.

| List               | Purpose                                                          |
| ------------------ | ---------------------------------------------------------------- |
| `AssetCatalogue`   | Master list of all IT assets with stock, category, status        |
| `AssetRequests`    | Staff requests for assets — status tracked through lifecycle     |
| `AssetAssignments` | Active assignments of assets to users — attestation tracked here |
| `Attestations`     | Quarterly attestation records submitted by users                 |
| `AppAdmins`        | Controls role access — IT Admin, Super Admin, Read-Only Admin    |
| `Notifications`    | In-app notifications written by flows, read by users             |

---

## Roles

| Role            | Access                       | Set via                |
| --------------- | ---------------------------- | ---------------------- |
| Super Admin     | All screens, all actions     | AppAdmins list         |
| IT Admin        | All screens, all actions     | AppAdmins list         |
| Read-Only Admin | All admin screens, view only | AppAdmins list         |
| Normal User     | User screens only            | Absence from AppAdmins |

---

## Power Automate Flows

| Flow                             | Trigger                                    | What it does                                                                           |
| -------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------------- |
| Flow 1 — Request Approval        | New row in `AssetRequests`                 | Starts approval, creates assignment on approval, emails requester, writes notification |
| Flow 2 — Attestation Reminder    | Quarterly recurrence schedule              | Resets `AttestedThisCycle = false` on all assignments, sends reminder emails           |
| Flow 3 — Attestation Alert       | New row in `Attestations`                  | Sends confirmation email to user, alerts IT if asset reported Missing or Lost          |
| Flow 4 — Assignment Notification | Row created/modified in `AssetAssignments` | Emails user when asset is assigned (when SerialNumber populated), writes notification  |

> **Flow 1 is critical.** Without it, approved requests do not create assignment records.
> **Flow 2 is critical.** Without it, the Attest screen shows 0 pending after the first quarter.
> **Flows 3 and 4** are optional for core functionality — they handle notifications only.

---

## Components

| Component       | Purpose                                                                                                            |
| --------------- | ------------------------------------------------------------------------------------------------------------------ |
| `cmpHeader`     | Top header bar — app name, screen title, user photo, role badge. Used on all 12 app screens.                       |
| `cmpNavigation` | Left sidebar nav gallery — driven by `colNavItems` collection. Role-aware — admin items only shown to admin roles. |

Both components require **Access app scope = On** on all custom properties to read design token variables.

---

## App.OnStart

All design tokens, role variables, navigation collection, and filter dropdown collections are defined here.

| What is set         | Details                                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 23 colour variables | Full navy palette from `clrPrimary` to `clrWhite`                                                                                     |
| Typography          | `fntSizeXS` through `fntSizeHero`, `fntFamily`                                                                                        |
| Spacing & radius    | `spcXS` through `spcXL`, `radSM` through `radPill`                                                                                    |
| Layout dimensions   | `dimHeaderH`, `dimSidebarW`, `dimLogoW`, `dimAvatarW`                                                                                 |
| Role variables      | `isAdmin`, `isITAdmin`, `isSuperAdmin`, `isReadOnlyAdmin`, `isEditable`                                                               |
| Navigation          | `colNavItems` — built conditionally by role                                                                                           |
| Filter collections  | `colCategoryOptions`, `colStatusOptions`, `colUrgencyOptions`, `colReqStatusOptions`, `colConditionOptions`, `colAssignStatusOptions` |

---

## Screen Overview

### WelcomeScreen
**Role:** All users | **Purpose:** App entry screen shown while App.OnStart completes.

A timer fires after 1.5 seconds and routes the user to `scrDashboard` (admin roles) or `scrHome` (normal users) based on the `isAdmin` variable. No button click required.

**Controls:** Background rectangle, logo, app name label, tagline label, loading label, powered-by label, Timer (hidden, AutoStart = true).

![WelcomeScreen](../assets/screen-welcome.png)

---

### scrDashboard — Dashboard
**Role:** Admin only | **Purpose:** Overview of app activity with KPI counts and recent request feed.

Shows 4 KPI cards (Total Assets, Pending Requests, Approved This Month, Overdue Attestation) and a scrollable activity feed of recent requests with requester name, asset, status badge, and date.

**Tree View structure:**
```
scrDashboard
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── dash_conKPIRow
              │     ├── dash_conKPI1  (Total Assets)
              │     ├── dash_conKPI2  (Pending Requests)
              │     ├── dash_conKPI3  (Approved This Month)
              │     └── dash_conKPI4  (Overdue Attestation)
              ├── dash_lblFeedHeading
              ├── dash_galActivity  (recent requests, top 10)
              └── dash_btnRefresh
```

![scrDashboard](../assets/screen-dashboard.png)

---

### scrAdminCat — Asset Catalogue
**Role:** Admin only | **Purpose:** Browse, add, edit, and retire assets in the catalogue.

Gallery view with search and category/status filters. Clicking Add New or Edit opens a full-width form panel that replaces the gallery. The same form handles both Add and Edit — `NewForm()` clears it, `EditForm()` populates it. Save closes the form and returns to the gallery.

**Tree View structure:**
```
scrAdminCat
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── cat_conFilterRow
              │     ├── cat_txtSearch
              │     ├── cat_ddCategory
              │     ├── cat_ddStatus
              │     └── cat_btnAddNew  (Visible = isEditable)
              └── cat_conContent
                    ├── cat_conList  (Visible = !showAssetPanel)
                    │     └── cat_galCatalogue
                    │           ├── cat_lblName, cat_lblCategory, cat_lblStock
                    │           ├── cat_lblStatus, cat_btnEdit, cat_rectDivider
                    └── cat_conForm  (Visible = showAssetPanel)
                          ├── cat_lblFormTitle
                          ├── cat_frmAsset  (Edit Form, DataSource = AssetCatalogue)
                          │     └── cat_cardTitle, cat_cardCategory, cat_cardStatus
                          │         cat_cardStockQty, cat_cardDescription
                          │         cat_cardAvgLife, cat_cardUnitCost
                          ├── cat_btnSave
                          ├── cat_btnRetire
                          └── cat_btnCancel
```

![scrAdminCat](../assets/screen-admin-catalogue.png)

---

### scrAssignments — Asset Assignments
**Role:** Admin only | **Purpose:** View all asset assignments with search by employee email or asset name and status filter.

Read-only view for IT admins. Shows assignment ID, asset name, assigned user (resolved via Office365Users), status badge, and attestation status. No edit form — assignments are created by Flow 1 on approval.

**Tree View structure:**
```
scrAssignments
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── asgn_conSearchRow
              │     ├── asgn_txtEmployee
              │     ├── asgn_txtAsset
              │     └── asgn_ddStatus
              └── asgn_galAssignments
                    ├── asgn_lblTitle, asgn_lblAsset
                    ├── asgn_lblAssignedTo  (Office365Users display name)
                    ├── asgn_lblStatus, asgn_lblAttested
                    └── asgn_rectDivider
```

![scrAssignments](../assets/screen-assignments.png)

> 🔵 Gallery uses `If` wrapper on Items formula to prevent blank on page load when dropdown has not registered its default value.

---

### scrApprove — Approve Requests
**Role:** Admin only | **Purpose:** Review and approve or deny pending asset requests.

Split-panel layout. Left panel shows the pending requests gallery (55% width). Selecting a row loads the justification, IT notes input, and expected delivery date picker in the right panel. Approve patches status and triggers Flow 1 downstream. Deny requires a mandatory IT note.

> 🔵 **FLOW 1** — Approve/Deny here triggers Flow 1 to create assignment, email requester, and write notification.

**Tree View structure:**
```
scrApprove
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── appr_conFilterRow
              │     └── appr_ddUrgency
              └── appr_conContent  (FillPortions = 1, Horizontal)
                    ├── appr_galPending  (Width 55%)
                    │     ├── appr_lblTitle, appr_lblRequester
                    │     ├── appr_lblAsset, appr_lblUrgency
                    │     └── appr_rectDivider
                    └── appr_conDetail  (FillPortions = 1)
                          ├── appr_lblJustLabel, appr_lblJustification
                          ├── appr_txtITNotes  (classic TextInput — supports Reset())
                          ├── appr_dpDelivery  (classic DatePicker — supports Reset())
                          ├── appr_btnApprove  (Visible = isEditable)
                          ├── appr_btnDeny     (Visible = isEditable)
                          └── appr_btnCancel   (Text = "Clear")
```

![scrApprove](../assets/screen-approve.png)

> Classic controls required for `appr_txtITNotes` and `appr_dpDelivery` — ModernTextInput and ModernDatePicker do not respond to `Reset()`.

---

### scrAttReview — Attestation Review
**Role:** Admin only | **Purpose:** Monitor quarterly attestation progress and review disputed/missing assets.

Shows current cycle label, completion percentage with progress bar, a gallery of users who have not yet attested, and a gallery of attestations flagged as Confirmed = false (disputed or missing). IT can mark disputed items as reviewed.

**Tree View structure:**
```
scrAttReview
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── attr_lblCycle
              ├── attr_lblCompletion
              ├── attr_rectProgressBg  (background bar)
              ├── attr_rectProgress    (fill bar, Width = Parent.Width * completionPct / 100)
              ├── attr_lblNonAttestHeading
              ├── attr_galNonAttesters  (Filter: !AttestedThisCycle, Active)
              │     ├── attr_lblNonTitle, attr_lblNonDate
              │     └── attr_rectDivider
              ├── attr_lblDisputeHeading
              └── attr_galDisputed  (Filter: Confirmed = false, ITReviewed = false)
                    ├── attr_lblDispTitle, attr_lblDispComments
                    ├── attr_btnReviewed  (Visible = isEditable)
                    └── attr_rectDivider2
```

![scrAttReview](../assets/screen-att-review.png)

> Items formula uses `!AttestedThisCycle` not `= false` — blank Yes/No columns in SharePoint do not equal false.

---

### scrReports — Reports & Export
**Role:** Admin only | **Purpose:** Switch between report types and filter by date range.

Dropdown selects report type (All Assets, Request History, Attestation Compliance, Asset Age). Date pickers filter where applicable. Gallery displays the selected data source. No export connector is built — Phase 2 feature.

**Tree View structure:**
```
scrReports
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── rpt_ddReportType  (static array — not a SPO choice column)
              ├── rpt_conDateRow
              │     ├── rpt_dpStart  (Default = Today() - 90 days)
              │     └── rpt_dpEnd   (Default = Today())
              ├── rpt_btnGenerate
              └── rpt_galData  (Items switches by report type selection)
                    ├── rpt_lblTitle
                    └── rpt_rectDivider
```

![scrReports](../assets/screen-reports.png)

---

### scrHome — My Home
**Role:** All users | **Purpose:** Personalised landing screen with attestation reminder banner and quick action buttons.

Shows welcome message with user name, today's date, and an attestation reminder banner (only visible when `varOverdueCount > 0`). Three quick action buttons navigate to New Request, My Assets, and Notifications.

**Tree View structure:**
```
scrHome
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── home_lblWelcome
              ├── home_lblDate
              ├── home_conReminder  (Visible = varOverdueCount > 0)
              │     ├── home_lblReminderText
              │     └── home_btnGoAttest
              ├── home_lblActions
              └── home_conActions
                    ├── home_btnNewRequest
                    ├── home_btnMyAssets
                    └── home_btnNotif  (shows unread count)
```

![scrHome](../assets/screen-home.png)

---

### scrNewRequest — New Request
**Role:** All users | **Purpose:** Browse available assets and submit a new request.

Horizontal gallery of active assets from AssetCatalogue. Tapping a card selects it (`selectedAsset` variable). Form row below has quantity, urgency dropdown, and needed-by date. Justification text input enforces minimum 20 characters. Submit button validates, patches to AssetRequests, and navigates to My Requests.

> 🔵 **FLOW 1** — Submit creates a row in AssetRequests which triggers Flow 1 to start the approval process.

**Tree View structure:**
```
scrNewRequest
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── req_galCatBrowse  (Horizontal gallery, Active assets)
              │     ├── req_rectCardBg  (Rectangle — card background, selection highlight)
              │     ├── req_lblCardName
              │     ├── req_lblCardCat
              │     └── req_lblCardStock
              ├── req_lblSelected  (shows selected asset name)
              ├── req_conFormRow
              │     ├── req_txtQty      (Default = "1")
              │     ├── req_ddUrgency   (Default = Medium)
              │     └── req_dpNeededBy  (Default = Today() + 7 days)
              ├── req_txtJustification  (multiline, min 20 chars enforced)
              └── req_btnSubmit
```

![scrNewRequest](../assets/screen-new-request.png)

> GroupContainer does not support OnSelect. Card selection uses a Rectangle (`req_rectCardBg`) with individual labels each having `OnSelect = Set(selectedAsset, ThisItem)`.

---

### scrMyRequests — My Requests
**Role:** All users | **Purpose:** View the user's own request history with status filter.

Gallery filtered by `RequestedByEmail = User().Email`. Status dropdown filters by lifecycle stage. Denied requests show a Re-submit button (navigates to scrNewRequest). Pending requests show a Cancel button (patches status to Cancelled).

**Tree View structure:**
```
scrMyRequests
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── mreq_ddFilter  (Items = colReqStatusOptions, Default = "All")
              └── mreq_galRequests  (FillPortions = 1)
                    ├── mreq_lblTitle, mreq_lblAsset, mreq_lblDate
                    ├── mreq_lblStatus  (colour-coded badge)
                    ├── mreq_btnResubmit  (Visible = Status = "Denied")
                    ├── mreq_btnCancel   (Visible = Status = "Pending")
                    └── mreq_rectDivider
```

![scrMyRequests](../assets/screen-my-requests.png)

---

### scrMyAssets — My Assets
**Role:** All users | **Purpose:** View all active assets assigned to the logged-in user.

Gallery filtered by `AssignedToEmail = User().Email` and `Status = Active`. Shows asset name, serial number, asset tag, attested/overdue badge, and warranty expiry (red if within 30 days, hidden if blank).

**Tree View structure:**
```
scrMyAssets
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              └── ast_galMyAssets  (FillPortions = 1)
                    ├── ast_lblAssetName
                    ├── ast_lblSerial
                    ├── ast_lblTag
                    ├── ast_lblAttested  (Attested / Overdue badge)
                    ├── ast_lblWarranty  (Visible = !IsBlank(WarrantyExpiry))
                    └── ast_rectDivider
```

![scrMyAssets](../assets/screen-my-assets.png)

> `AssignedToEmail` in SharePoint must match `User().Email` exactly (full UPN). Test data must use the actual login UPN of the test user.

---

### scrAttest — Attest My Assets
**Role:** All users | **Purpose:** Quarterly asset attestation — confirm possession and condition of each assigned asset.

Gallery shows assets where `!AttestedThisCycle` and `AssignedToEmail = User().Email`. Per-row condition dropdown and Confirm button. Confirming adds to `colAttestQueue` local collection and increments counter. Submit All writes to Attestations list and sets `AttestedThisCycle = true` on each AssetAssignment row.

> 🔵 **FLOW 3** (optional) — Submit All creates Attestation rows which trigger Flow 3 to send confirmation emails and alert IT on Missing/Lost items.
> 🔵 **FLOW 2** (scheduled) — Resets `AttestedThisCycle` quarterly so assets reappear in this screen each cycle.

**Tree View structure:**
```
scrAttest
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── att_lblProgress  ("[n] of [total] assets confirmed")
              ├── att_galAttest  (FillPortions = 1)
              │     ├── att_lblAssetName, att_lblSerial
              │     ├── att_ddCondition  (per-row condition dropdown)
              │     ├── att_btnConfirm   (adds to colAttestQueue)
              │     └── att_rectDivider
              └── att_btnSubmitAll  (writes to Attestations + updates AssetAssignments)
```

![scrAttest](../assets/screen-attest.png)

> `colAttestQueue` is cleared on OnVisible. Navigate away before Submit All loses all confirmations — this is by design.

---

### scrNotif — Notifications
**Role:** All users | **Purpose:** In-app notification inbox — unread items highlighted, tap to mark read.

Gallery filtered by `RecipientEmail = User().Email`, sorted newest first. Unread items have pale blue background and bold title. Tapping any row marks it as read. Mark All Read button patches all unread rows at once.

> 🔵 **FLOWS 1, 3, 4** write to the Notifications list. Without flows built, this screen is always empty.

**Tree View structure:**
```
scrNotif
  └── Grid1
        ├── HeaderContainer → cmpHeader
        ├── SidebarContainer → cmpNavigation
        └── MainContainer
              ├── notif_conHeader
              │     ├── notif_lblUnread  (FillPortions = 1)
              │     └── notif_btnMarkAll
              └── notif_galNotifications  (FillPortions = 1)
                    ├── notif_rectBg   (pale blue if unread)
                    ├── notif_lblTitle (Bold if unread)
                    ├── notif_lblMessage  (Left 80 chars)
                    ├── notif_lblType, notif_lblDate
                    ├── notif_lblUnreadDot  (● indicator)
                    └── notif_rectDivider
```

![scrNotif](../assets/screen-notifications.png)

---

## Key Confirmed Patterns

| Pattern                   | Rule                                                                                      |
| ------------------------- | ----------------------------------------------------------------------------------------- |
| Choice field filter       | Use `Status.Value = "Pending"` not `Status = "Pending"`                                   |
| Yes/No blank filter       | Use `!AttestedThisCycle` not `AttestedThisCycle = false`                                  |
| Typed blank variable      | Use `First(Filter(list, false))` not `Blank()`                                            |
| Gallery blank on load     | Wrap Items in `If(all empty, FullTable, Filter(...))`                                     |
| Reset inputs mid-session  | Use classic TextInput and classic DatePicker — Modern controls ignore `Reset()`           |
| Card selection in gallery | Use Rectangle with OnSelect — GroupContainer has no OnSelect                              |
| DateAdd enum              | Use `TimeUnit.Days` not `Days`                                                            |
| YAML block scalar         | Use `\|-` for any formula containing `{...}`, `:`, or special characters                  |
| Component variables       | Access app scope = On required on all custom properties                                   |
| FillPortions              | Required on galleries and containers inside vertical AutoLayout to claim remaining height |

---

*IT Asset Request & Management App — Summary Reference*
*Vishnu WR — Microsoft Solution Architect — wrvishnu.com*