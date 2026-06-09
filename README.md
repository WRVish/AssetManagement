# IT Asset Request & Management System

> [!IMPORTANT]
> **⭐ Support the Project & Share Your Feedback!**
> * If you find this solution helpful, please **Star this repository** to show your support!
> * Have a feature request or suggestion? Head over to the **GitHub Discussions** tab to start a conversation or share your ideas!

A brief overview of the IT Asset Request and Management system.

---

## High-Level Architecture & Flow

The system operates across three main layers:

1. **Frontend**: Power Apps Canvas App (Tablet layout, utilizing modern components and Fluent design principles).
2. **Backend**: SharePoint Online (SPO) using 6 core lists:
   - `AssetCatalogue`: Master catalog of assets and stock.
   - `AssetRequests`: Staff requests and their lifecycle states.
   - `AssetAssignments`: Active assignments and attestation status.
   - `Attestations`: History of submitted attestation records.
   - `AppAdmins`: Role-based access control mappings (IT Admin, Super Admin, Read-Only).
   - `Notifications`: In-app notification history.
3. **Automation**: Power Automate (4 standard cloud flows managing approvals, quarterly reset schedules, attestation disputes, and assignment notifications).

### High-Level Flow
1. **Request**: Staff browses available catalogue assets, inputs needed details, and submits a request.
2. **Approval**: Power Automate triggers an approval task for the IT Admin.
3. **Assignment**: Upon approval, the flow automatically creates an active assignment record, updates stock levels in the catalogue, and sends notifications.
4. **Attestation**: Staff attests their assigned equipment possession and condition quarterly through the app.

---

## Available Screens

### Admin Screens
- **Dashboard**: High-level overview of KPI counts and a live activity feed.
- **Asset Catalogue**: Catalog browser and inline edit/create forms.
- **Approve Requests**: Split-panel interface to review justifications and approve/deny requests.
- **Attestation Review**: Progress tracking for active cycles and dispute management.
- **Reports & Export**: Reporting viewer based on category filters.

### User Screens
- **My Home**: Customized dashboard featuring quick action buttons and attestation alert banners.
- **New Request**: Horizontal card browser for requesting new assets.
- **My Requests**: Personal request status tracker.
- **My Assets**: Details of assigned equipment and warranty statuses.
- **Attest My Assets**: Quarterly asset confirmation and condition reporting.
- **Notifications**: Internal notification inbox.

---

## Customization & Solution Details

- The Power Apps package is provided as an **unmanaged solution** to allow for further customization, branding, and enhancement.
- Detailed step-by-step documentation, formulas, and schema mappings can be found in the [Asset Management System.md](Asset%20Management%20System.md) reference file.

---

## Author Profile

* **Author**: Wrvishnu
* **LinkedIn**: [vishnuwr](https://www.linkedin.com/in/vishnuwr)
* **Website**: [www.wrvishnu.com](https://www.wrvishnu.com)
* **Email**: info@wrvishnu.com
