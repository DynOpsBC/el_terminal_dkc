# Setup Runbook

## Sandbox

- Tenant: `7fa2357e-26f2-4174-8e16-a713981356b8`
- Environment: `CustomerSandbox`
- Company: `Demo Business Central`
- URL: `https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox?company=Demo%20Business%20Central`

## AL Install Steps

1. Open `al/` in Visual Studio Code with the AL extension on Windows.
2. Download symbols for Business Central 24.
3. Package the extension.
4. Publish to the sandbox with `schemaUpdateMode` set to `ForceSync` for initial scaffolding only.
5. Assign `DOPSWHS-ADMIN` to the sandbox test user.
6. Open Assisted Setup and verify the BCWMSApp setup tile opens the setup card.

## Configuration Checklist (per company)

> **Live tool:** open **Assisted Setup → "DynOps WMS Configuration Check"** (or Tell Me → "WMS Configuration Check",
> page **72261**). It evaluates every item below as ✅/⚠️/❌ and auto-applies the fixable ones via **Tümünü Düzelt**
> (Fix All) / **Seçiliyi Düzelt** (Fix selected). Direct URL (SandboxUS):
> `https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/SandboxUS/?page=72261&company=CRONUS%20USA%2C%20Inc.`

Run after install, before using the warehouse flows. Items marked **(required)** block the related feature.

- [ ] **Package No. for License Plates** — *required only if linking LPs to Item/Value ledger entries via standard BC `Package No.`* (the app's Warehouse Entry link uses the custom `DOPSWHS LP No.` field and needs none of this):
  1. **Inventory Setup → "Package Nos."** — assign a No. Series (master switch that enables package tracking in the environment).
  2. **Item Tracking Code** — create one with package tracking on (`Package Specific Tracking` = Yes; add `Package Warehouse Tracking` = Yes to carry the package onto warehouse docs; set `Package Info. Inbound/Outbound Must Exist` per policy).
  3. **Assign that Item Tracking Code** to every item that will be placed on an LP.
  4. Posting must write **item tracking lines** (reservation entries) with the package no., not just `Item Journal Line."Package No."` — a direct field assignment is dropped at posting for non-package-tracked items.
  > Alternative (no BC setup): keep the custom `DOPSWHS LP No.` field approach on Item Ledger Entry too, for one consistent join key across warehouse + inventory ledgers.
- [ ] **Warehouse Employee (required)** — register each operator/user as a Warehouse Employee on every bin-mandatory location (auto-seeded for the install user by `DOPSWHS E2E Test Data.EnsureWarehouseEmployee`; add other users manually). Without it, warehouse pages, OData and web services return *"You must first set up user X as a warehouse employee."*
- [ ] **Default location + bins (required)** — `DOPSWHS Setup."Default Location Code"` set to a bin-mandatory location; RECEIVE-1 / PICK-01 / BULK-01 / SHIP-01 bins exist. Note: Ad-Hoc Move (item reclass) needs a **non-directed** bin location; on directed locations use Directed Move.
- [ ] **Number series** — LP, SSCC, Count Sheet, Test Run, Quality Order series present (auto-seeded by Install/Upgrade).
- [ ] **Permission set** — assign `DOPSWHS-ADMIN` (or User/View) to the user.
- [ ] **Web service pages** — `DOPSWHSWarehouseShipment`, `DOPSWHSWarehousePick`, … published (auto by `DOPSWHS Web Svc Publisher`); verify in *Web Services* / OData root.
- [ ] **WMS App User Profile (per user)** — every operator should have a row in **WMS App User Profiles** (page 72263) so the mobile app sees the right Device Config, default location, only-mine filters, and tile visibility. Auto-seeded: a `DEFAULT` row + a row for the install user. Add a row per operator (or leave them on DEFAULT). Mobile fetches via `POST .../appUserProfiles('DEFAULT')/Microsoft.NAV.resolveCurrent` — the action ignores the bound key and resolves the **calling** user.
- [ ] **WMS App Roles (per user)** — open **WMS App Roles** (page 72274) and verify the 7 system roles are seeded (`OPERATOR`, `PICKER`, `RECEIVER`, `SHIPPER`, `COUNTER`, `QUALITY`, `INV_ADMIN`). Open the user's **WMS App User Profile** card and add one or more rows to the **Roles** sub-list. Effect is immediate and server-side: every BCWMS API page applies the user's role filters in OnOpenPage (e.g. `PICKER` sees only picks where `Assigned User ID = <them> OR blank`). Custom roles can be added freely; **system roles cannot be deleted**. Filter expression tokens: `%USER%`, `%LOC%` (= user's default location), `%TODAY%`, `%NOW%`.

## License Plate (WI Parity) — v1.7 added

The `DOPSWHS LP No.` field now propagates through the BC posting chain (matching Warehouse Insight): Warehouse Receipt/Shipment Header + posted twin, Purch. Rcpt. Line, Sales Shipment Line, Item Ledger Entry, Value Entry. Drive your OData reports off any of these tables — every stock movement carries the LP that touched it. Receipt-time scan stamps the Warehouse Receipt Header; subscribers carry it onto the posted line + ILE.

## External Dependencies

- Azure AD app registration for Android MSAL.
- Azure Function, SignalR, Key Vault, and Application Insights deployment for push relay.
- Microsoft PartnerSource object range expansion request to `72000-72499`.
