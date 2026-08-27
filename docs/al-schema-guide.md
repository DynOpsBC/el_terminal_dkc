# BCWMS AL Extension Schema Guide

Complete reference for Business Central extension data models, APIs, and entity relationships.

**Platform:** Business Central 24.0+  
**Extension:** DynOps WMS (Publisher: DynOps, ID prefix: DOPSWHS)  
**Object Range:** 72000 - 72499  
**Last Updated:** July 27, 2026

---

## Table of Contents

1. [Core Entity Models](#core-entities)
2. [API Endpoints](#api-endpoints)
3. [Enumerations](#enumerations)
4. [Entity Relationships](#relationships)
5. [Codeunits (Business Logic)](#codeunits)
6. [Common Patterns](#patterns)

---

## Core Entities

### 1. Warehouse Activity Header (Standard BC)

**Table:** `Warehouse Activity Header` (7302)  
**AL Extension:** `DOPSWHS Warehouse Activity Header Ext` (72429)

Core picking/putting/receiving document header.

**DOPSWHS Extension Fields:**

| Field No. | Name | Type | Description |
|-----------|------|------|-------------|
| 72400 | `DOPSWHS Pick Mode` | Enum | Multi / Bulk / Batch |
| 72401 | `DOPSWHS Vehicle No.` | Code[20] | Vehicle registration for delivery |
| 72402 | `DOPSWHS Main LP No.` | Code[20] | Shipping LP (tote) for picking |

**Example Usage (AL):**
```al
var
  WhseActivityHdr: Record "Warehouse Activity Header";
begin
  WhseActivityHdr.Get(WhseActivityHdr.Type::Pick, 'WHSEPICK-0001');
  if WhseActivityHdr."DOPSWHS Pick Mode" = WhseActivityHdr."DOPSWHS Pick Mode"::Multi then
    Message('Multi-order pick');
end;
```

---

### 2. Warehouse Activity Line (Standard BC)

**Table:** `Warehouse Activity Line` (7303)  
**AL Extension:** `DOPSWHS Warehouse Activity Line Ext` (72430)

Line-level picking/receiving details.

**DOPSWHS Extension Fields:**

| Field No. | Name | Type | Description |
|-----------|------|------|-------------|
| 72400 | `DOPSWHS Lot No.` | Code[50] | Batch/lot from item tracking |
| 72401 | `DOPSWHS Serial No.` | Code[50] | Serial number if applicable |
| 72402 | `DOPSWHS Source Bin Code` | Code[20] | Original bin for ad-hoc moves |

---

### 3. Pick Tote Assignment

**Table:** `DOPSWHS Pick Tote Assignment` (72330)  
**Pages:** 72342 (List), 72341 (Detail)

Maps picks to reusable totes/LPs for order grouping.

**Fields:**

| Field No. | Name | Type | Key | Description |
|-----------|------|------|-----|-------------|
| 1 | `Pick No.` | Code[20] | Yes | Reference to Warehouse Activity Header |
| 10 | `Tote LP No.` | Code[20] | | License Plate (container) for pick |
| 20 | `Assigned DateTime` | DateTime | | When tote was assigned |
| 30 | `Status` | Option | | Assigned / Used / Released |

**SQL Query Example:**
```sql
SELECT pta."Pick No.", pta."Tote LP No.", pta.Status
FROM "DOPSWHS Pick Tote Assignment" pta
WHERE pta."Pick No." LIKE 'WHSEPICK-%'
  AND pta.Status = 1; -- Used
```

---

### 4. Packing Order (DOPSWHS)

**Table:** `DOPSWHS Packing Order` (72326)  
**Pages:** 72344-72346 (3 pack mode worksheets), 72340 (List), 72339 (Card)

Packing session for order fulfillment.

**Fields:**

| Field No. | Name | Type | Key | Lookup | Description |
|-----------|------|------|-----|--------|-------------|
| 1 | `No.` | Code[20] | Yes | | Auto-sequenced PI prefix |
| 10 | `Sales Order No.` | Code[20] | | Sales Header | Source order |
| 20 | `Pick No.` | Code[20] | | Warehouse Activity Hdr | Source pick reference |
| 30 | `Status` | Enum | | | Ready / In Progress / Completed |
| 40 | `Pack Mode` | Enum | | | Solo / Bulk / Batch |
| 60 | `Customer Name` | Text[100] | | | Denormalized for display |
| 70 | `Location Code` | Code[10] | | Location | Warehouse location |
| 80 | `Started By User` | Code[50] | | | WMS operator username |
| 90 | `Ready DateTime` | DateTime | | | When all items packed |
| 100 | `Completed DateTime` | DateTime | | | When box scanned (shipped) |

**AL Binding Actions:**
```al
[HttpPost]
procedure startPackingAs(userId: Code[50])
// Start session, stamp operator
[HttpPatch]
procedure setBoxForOrder(boxLpNo: Code[20])
// Mark order fully packed + boxed, post shipment
```

---

### 5. Packing Session Line

**Table:** `DOPSWHS Packing Session Line` (72327)  
**API:** Embedded in Packing Order API

Line item within packing session.

**Fields:**

| Field No. | Name | Type | Mandatory | Description |
|-----------|------|------|-----------|-------------|
| 1 | `Packing Order No.` | Code[20] | Yes | FK to Packing Order |
| 2 | `Line No.` | Integer | Yes | Sequence within session |
| 10 | `Pick Line No.` | Integer | | Source pick line |
| 20 | `Item No.` | Code[20] | Yes | Material being packed |
| 30 | `Quantity` | Decimal | Yes | Units to pack |
| 40 | `Quantity Packed` | Decimal | | Cumulative scanned qty |
| 50 | `Box LP No.` | Code[20] | | Shipping box/carton LP |
| 60 | `Status` | Option | | Open / Packed / Invoiced |

---

### 6. License Plate (DOPSWHS)

**Table:** `DOPSWHS License Plate` (72309)  
**Pages:** 72310 (List), 72311 (Card)  
**API:** Pages 72092-72093

Container/tote for warehouse materials.

**Key Fields:**

| Field No. | Name | Type | Mandatory | Description |
|-----------|------|------|-----------|-------------|
| 1 | `No.` | Code[20] | Yes | Barcode, e.g. "T-06-K0" (tote) or "CTN-001" (carton) |
| 10 | `LP Template No.` | Code[20] | | Reusable template (Batch, Mono-SKU, PALLET) |
| 20 | `Type` | Option | | Reusable / Temp |
| 30 | `Bin Code` | Code[20] | | Current bin location |
| 40 | `Status` | Enum | | Built / Assigned / Used / Unbuilt |
| 50 | `Item No.` | Code[20] | | Primary item (for sorted LPs) |
| 55 | `Source Bin Code` | Code[20] | | Original bin (ad-hoc moves) |

**API Example:**
```http
POST /licensePlates
Content-Type: application/json

{
  "no": "LP-2026-0042",
  "lpTemplateNo": "PALLET",
  "type": 0,
  "status": "Built"
}

PATCH /licensePlates('LP-2026-0042')/setBoxForOrder
Content-Type: application/json

{
  "boxLpNo": "BOX-98765"
}
```

---

### 7. Local User (DOPSWHS)

**Table:** `DOPSWHS Local User` (72284)  
**Pages:** 72285 (List), 72286 (Card)  
**API:** Page 72287

WMS operator credentials for terminal login (no Azure AD).

**Fields:**

| Field No. | Name | Type | Mandatory | Description |
|-----------|------|------|-----------|-------------|
| 1 | `Username` | Code[20] | Yes | Operator ID, e.g. "wms-op-01" |
| 10 | `Display Name` | Text[100] | | Full name for UI |
| 20 | `Password Hash` | Text[128] | | SHA-256(salt + password) |
| 21 | `Password Salt` | Text[40] | | Per-record GUID salt |
| 30 | `Default Location Code` | Code[10] | | Warehouse location |
| 60 | `Disabled` | Boolean | | Revoke login access |
| 70 | `Last Login DateTime` | DateTime | | Readonly, audit trail |

---

### 8. WMS Activity Log (DOPSWHS)

**Table:** `DOPSWHS WMS Activity Log` (72360)  
**Pages:** 72361 (List), 72362 (Card)  
**API:** Page 72363

Operator action audit trail (scans, assignments, completions).

**Fields:**

| Field No. | Name | Type | Example |
|-----------|------|------|---------|
| 1 | `Entry No.` | BigInteger | 1000001 (auto) |
| 10 | `Timestamp` | DateTime | 2026-07-27T14:30:45Z |
| 20 | `Local User` | Code[20] | wms-op-01 |
| 30 | `Action` | Code[30] | ScanItem / AssignPick / CompleteOrder |
| 31 | `Action Status` | Option | Success (0) / Fail (1) / Timeout (2) |
| 40 | `Document Type` | Code[20] | Pick / PutAway / Shipment |
| 41 | `Document No.` | Code[20] | WHSEPICK-0001 |
| 50 | `Item No.` | Code[20] | 1000 |
| 60 | `Details` | Text[500] | JSON: {"binCode": "A-01-01", "error": "..."}  |

---

## API Endpoints

### Core ODATA v4 Resources

All endpoints use `/odata/v4` prefix. Tenant/environment must be set in BC URL.

#### Warehouse Activity (Picking)

**Base Resource:** `warehouseActivities`

```http
GET /warehouseActivities?$filter=Type eq 0 and Status eq 'Open'
  &$expand=Lines
  &$select=No.,Type,Status,AssignedUserId,DopswhsPickMode

GET /warehouseActivities('WHSEPICK-0001')

PATCH /warehouseActivities('WHSEPICK-0001')/assignedUserId
Body: { "value": "wms-op-01" }

POST /warehouseActivities('WHSEPICK-0001')/Microsoft.NAV.completeActivity
```

#### Packing Order

**Base Resource:** `packingOrders`

```http
GET /packingOrders?$filter=Status eq 'Ready' or Status eq 'In Progress'
  &$expand=Lines
  &$orderby=StartedDateTime desc

POST /packingOrders
Body: {
  "salesOrderNo": "SO-001234",
  "packMode": "Solo",
  "operatorUserId": "wms-op-02"
}

PATCH /packingOrders('PI000001')/setBoxForOrder
Body: { "boxLpNo": "BOX-98765" }
```

#### License Plate

**Base Resource:** `licensePlates`

```http
GET /licensePlates?$select=No.,Status,BinCode,ItemNo.,SourceBinCode

POST /licensePlates
Body: {
  "no": "LP-2026-0042",
  "lpTemplateNo": "PALLET",
  "status": "Built"
}

PATCH /licensePlates('LP-2026-0042')/transfer
Body: {
  "targetLpNo": "LP-2026-0043",
  "targetBinCode": "B-02-03"
}
```

#### Local User (Auth)

**Base Resource:** `localUsers`

```http
POST /localUsers('wms-op-01')/Microsoft.NAV.verify
Body: { "password": "wms1234" }
Response: { "value": "Operator 01" } // Display name if verified

GET /localUsers?$select=Username,DisplayName,DefaultLocationCode
```

#### WMS Activity Log

**Base Resource:** `wmsActivityLogs`

```http
GET /wmsActivityLogs?$filter=LocalUser eq 'wms-op-01'
  &$orderby=Timestamp desc
  &$top=100

POST /wmsActivityLogs
Body: {
  "timestamp": "2026-07-27T14:30:45Z",
  "localUser": "wms-op-01",
  "userDisplayName": "Operator 01",
  "action": "ScanItem",
  "actionStatus": 0,
  "documentType": "Pick",
  "documentNo": "WHSEPICK-0001",
  "lineNo": 1,
  "itemNo": "1000",
  "quantity": 5,
  "details": "{\"binCode\": \"A-01-01\", \"lotNo\": \"LOT-2026\"}"
}
```

---

## Enumerations

### Pick Mode

| Name | Value | Description |
|------|-------|-------------|
| Multi | 0 | Multiple sales orders in one pick + bin walk |
| Bulk | 1 | Same item across orders, per-order invoice |
| Batch | 2 | Mono-SKU batch, tote scanned once |

**AL Usage:**
```al
enum 72349 "DOPSWHS Pick Mode"
{
    value(0; "Multi") { Caption = 'Çoklu'; }
    value(1; "Bulk")  { Caption = 'Toplu'; }
    value(2; "Batch") { Caption = 'Parti'; }
}
```

### Pack Mode

| Name | Value | Description |
|------|-------|-------------|
| Solo | 0 | Box → items (one item per box) |
| Bulk | 1 | Items → per-order box (invoice per share) |
| Batch | 2 | Mono-SKU batch (item closes order) |

### License Plate Status

| Name | Value | Description |
|------|-------|-------------|
| Built | 0 | LP created, contains items |
| Assigned | 1 | LP assigned to pick/packing |
| Used | 2 | LP consumed (shipment posted) |
| Unbuilt | 3 | LP deleted / released |

### WMS Activity Action Status

| Name | Value | Description |
|------|-------|-------------|
| Success | 0 | Operation completed |
| Fail | 1 | Operation failed (API error, validation) |
| Timeout | 2 | Operation timed out (network) |

---

## Relationships

### ER Diagram (Core)

```
Sales Order (5107)
    ├─ Sales Line (5108)
    │   └─ Warehouse Activity Line (7303) [Source Type=Sales Line]
    │       └─ Warehouse Activity Header (7302)
    │           ├─ DOPSWHS Pick Tote Assignment (72330)
    │           │   └─ DOPSWHS License Plate (72309)
    │           │
    │           └─ DOPSWHS Packing Order (72326)
    │               └─ DOPSWHS Packing Session Line (72327)
    │                   ├─ Item (27)
    │                   └─ License Plate (box)
    │
    └─ Sales Shipment Header (110)
        └─ Sales Shipment Line (111)
            └─ Item Ledger Entry (32)
```

### Cardinality

| From | To | Relation | Example |
|------|----|-----------| --------|
| Sales Order | Warehouse Activity Header (Pick) | 1:* | 1 SO → N picks (multiple per mode) |
| Warehouse Activity Header | Pick Tote Assignment | 1:1 | 1 pick → 1 tote LP |
| Sales Order → Packing Order | N:1 | N orders → 1 batch session (bulk mode) |
| Packing Session Line | Box LP | N:1 | N lines → 1 box per order |
| License Plate | Bin | N:1 | N LPs per bin |
| Local User | Warehouse Activity | 1:* | 1 operator → N picks assigned |

---

## Codeunits

### Pick Management (72427)

Core picking workflow orchestration.

**Key Procedures:**

```al
codeunit 72427 "DOPSWHS Pick Mgmt"
{
    // Assign pick to operator (updates Warehouse Activity Header."Assigned User ID")
    procedure AssignToMe(PickNo: Code[20]; OperatorUserId: Code[50])
    
    // Verify pick line completion (checks qty, lot, serial)
    procedure VerifyPickLine(PickNo: Code[20]; LineNo: Integer; Qty: Decimal; LotNo: Code[50]; SerialNo: Code[50])
    
    // Register pick (move from "Open" → "Registered")
    procedure RegisterPick(PickNo: Code[20])
    
    // Create multi-order pick from sales order list (groups by location + bin)
    procedure CreateGroupedPick(SalesOrderNos: Code[250]; OperatorUserId: Code[50]; PickMode: Enum "DOPSWHS Pick Mode")
}
```

### Pack Station Management (72334)

Packing workflow (all 3 modes).

```al
codeunit 72334 "DOPSWHS Pack Station Mgmt"
{
    // Initialize packing session
    procedure StartOrderSession(OrderNo: Code[20]; OperatorUserId: Code[50]) SessionNo: Code[20]
    
    // Scan item → complete line or accumulate qty
    procedure HandleScan(PackingOrderNo: Code[20]; ItemNo: Code[20]; Qty: Decimal; LotNo: Code[50])
    
    // Scan box → complete order + post shipment + invoice
    procedure SetBoxForOrder(PackingOrderNo: Code[20]; BoxLpNo: Code[20])
    
    // Post shipment + generate invoice (IWX integration if configured)
    local procedure PostSalesOrderShipAndInvoice(SalesOrderNo: Code[20])
}
```

### Local Auth Management (72286)

User authentication and provisioning.

```al
codeunit 72286 "DOPSWHS Local Auth Mgmt"
{
    // Register new operator + hash password
    procedure Register(Username: Code[20]; DisplayName: Text[100]; Password: Text[50]; LocationCode: Code[10]; BinCode: Code[20])
    
    // Verify login (hash password + salt, compare with stored hash)
    procedure VerifyPassword(Username: Code[20]; Password: Text[50]): Boolean
    
    // Update last login timestamp
    procedure RecordLogin(Username: Code[20])
    
    // Disable operator (soft delete, login blocked)
    procedure Disable(Username: Code[20])
}
```

### Multi-Order Pick (72338)

Grouping algorithm for multi-pick batches.

```al
codeunit 72338 "DOPSWHS Multi Order Pick"
{
    // Group sales orders by location + bin walk sequence
    procedure GroupByLocationAndBin(SalesOrderNos: Code[250]): Report "DOPSWHS Multi Order Pick"
}
```

---

## Common Patterns

### Pattern 1: Bound Action with Parameter

**AL Definition:**
```al
page 72093 "DOPSWHS License Plate API"
{
    [HttpPatch]
    procedure transfer(targetLpNo: Code[20]; targetBinCode: Code[20])
    var
        LP: Record "DOPSWHS License Plate";
    begin
        LP.Get(Rec.No.);
        LP.Transfer(targetLpNo, targetBinCode);
    end;
}
```

**HTTP Call:**
```http
PATCH /licensePlates('LP-001')/transfer
Content-Type: application/json

{
  "targetLpNo": "LP-002",
  "targetBinCode": "B-01-01"
}
```

### Pattern 2: FlowField for Aggregation

```al
table 72330 "DOPSWHS Pick Tote Assignment"
{
    fields
    {
        field(1; "Pick No."; Code[20]) { }
        field(10; "Tote LP No."; Code[20]) { }
        field(100; "Tote Item Count"; Integer) 
        {
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS License Plate Line" where("LP No." = field("Tote LP No.")));
            Editable = false;
        }
    }
}
```

### Pattern 3: DateTime Journalization

Always use `CurrentDateTime()` (UTC) for audit:

```al
trigger OnInsert()
begin
    "Created DateTime" := CurrentDateTime();
    "Created By" := CopyStr(UserId(), 1, 50);
end;

trigger OnModify()
begin
    "Modified DateTime" := CurrentDateTime();
end;
```

### Pattern 4: OData Security (Tenant Isolation)

All API pages use standard BC company/environment context:

```al
page 72363 "DOPSWHS WMS Activity Log API"
{
    PageType = API;
    SourceTable = "DOPSWHS WMS Activity Log";
    ApplicationArea = All;
    APIVersion = '2.0';
    APIPublisher = 'dynops';
    APIGroup = 'wms';
    ODataKeyFields = "Entry No.";
    // Implicit: filtered to current company in context
}
```

---

## Development Guidelines

### Adding New Fields to Existing Tables

Use **table extensions** (suffix `.TableExt.al`) to avoid breaking existing records:

```al
tableext 72430 "DOPSWHS Pick Tote Assignment Ext" extends "Pick Tote Assignment"
{
    fields
    {
        field(72400; "DOPSWHS New Field"; Code[20]) { }
    }
}
```

### Exposing Business Logic via API

Prefer **bound actions** on API pages over stored procedures:

```al
page 72093 "API"
{
    [HttpPost]
    procedure assignToOperator(userId: Code[50])
    begin
        Rec."Assigned User ID" := userId;
        Rec.Modify();
    end;
}
```

### Error Handling

Use `Error()` for user-facing messages; BC framework handles HTTP 400 translation:

```al
if Item."Unit Cost" <= 0 then
    Error('Item %1 has no cost defined. Cannot pick.', Item."No.");
```

---

## SQL Query Examples

### Find pending picks by operator
```sql
SELECT wah."No.", wah."Assigned User ID", COUNT(wal."Line No.") as LineCount
FROM "Warehouse Activity Header" wah
JOIN "Warehouse Activity Line" wal ON wah."No." = wal."Activity No."
WHERE wah.Type = 0  -- Pick
  AND wah.Status = 0  -- Open
  AND wah."Assigned User ID" = 'wms-op-01'
GROUP BY wah."No.", wah."Assigned User ID"
ORDER BY wah."Source No.";
```

### Activity log by operator (last 24 hours)
```sql
SELECT Local_User, COUNT(*) as ActionCount, 
       COUNT(CASE WHEN Action_Status = 0 THEN 1 END) as SuccessCount
FROM "DOPSWHS WMS Activity Log"
WHERE Timestamp >= DATEADD(hour, -24, GETUTCDATE())
GROUP BY Local_User
ORDER BY SuccessCount DESC;
```

---

## References

- **BC AL Documentation:** https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-dev-overview
- **OData v4 Spec:** https://www.odata.org/documentation/
- **BCWMS Source:** [al/src/](../al/src/) directory in this repo
- **API Test:** Use Postman or BC API browser (Services page 6700)

