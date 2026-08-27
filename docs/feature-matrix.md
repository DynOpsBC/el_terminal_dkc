# BCWMS v1.10+ Feature Matrix

Comprehensive overview of WMS capabilities across platforms and user roles.

**Last updated:** July 27, 2026  
**Version:** 1.10.0 GA

---

## Platform Legend

| Icon | Platform | Description |
|------|----------|-------------|
| 📱 | **Terminal** | Android handheld app (com.dynops.bcwms) for warehouse operators |
| 🖥️ | **OpsConsole** | Web-based manager dashboard (BC control add-in, SaaS PWA) |
| 💼 | **BC Native** | Business Central in-client pages (72xxx object range) |
| ✅ | **Full Support** | Feature complete and tested |
| ⚡ | **Partial** | Limited functionality or roadmap feature |
| ❌ | **Not Available** | Feature not implemented on this platform |

---

## Role Definitions

| Role | Description | Primary Devices | Features |
|------|-------------|-----------------|----------|
| **Picker** | Warehouse material handling — inbound/outbound picking | Terminal 📱 | Picking, Ad-Hoc Move, Directed Move, Quality (limited) |
| **Packer** | Order fulfillment — packing/boxing for shipment | Terminal 📱 | Packing (all 3 modes), Quality, Shipping |
| **Receiver** | Warehouse inbound — goods receipt and putaway | Terminal 📱 | Receiving, PutAway |
| **Manager** | Warehouse supervision — task assignment, monitoring | OpsConsole 🖥️, BC Native 💼 | All operational features, reporting, user management |
| **Admin** | System administrator — configuration, licensing | BC Native 💼 | All features, system setup, user provisioning |

---

## Feature Matrix by Role

### 1. PICKING (Picking material for orders)

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **List unassigned picks** | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Self-assign pick** | ✅ | ❌ | ❌ | ✅ | N/A | ✅ |
| **Reassign pick** | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Bin-directed picking** | ✅ | ❌ | ❌ | N/A | N/A | N/A |
| **Item scan + quantity** | ✅ | ❌ | ❌ | N/A | N/A | N/A |
| **Lot/Serial tracking** | ✅ | ⚡ | ❌ | N/A | N/A | N/A |
| **Multi-order picks** | ✅ | ❌ | ❌ | ✅ | ✅ | ⚡ |
| **Pick mode (Multi/Bulk/Batch)** | ✅ | ❌ | ❌ | ✅ | N/A | ✅ |
| **Tote/LP assignment** | ✅ | ❌ | ❌ | N/A | N/A | ✅ |
| **Register pick** | ✅ | ❌ | ❌ | N/A | N/A | ✅ |
| **Short-pick reporting** | ✅ | ❌ | ❌ | ✅ | N/A | ✅ |
| **Pick history/audit** | ⚡ | ❌ | ❌ | ✅ | ✅ | ✅ |

### 2. PACKING (Packing orders for shipment)

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Packing session list** | ❌ | ✅ | ❌ | ✅ | N/A | ✅ |
| **Pack mode: Solo** | ❌ | ✅ | ❌ | ✅ | N/A | ✅ |
| **Pack mode: Bulk** | ❌ | ✅ | ❌ | ✅ | N/A | ✅ |
| **Pack mode: Mono-SKU** | ❌ | ✅ | ❌ | ✅ | N/A | ✅ |
| **Scan tote/LP** | ❌ | ✅ | ❌ | N/A | N/A | N/A |
| **Scan box** | ❌ | ✅ | ❌ | N/A | N/A | N/A |
| **Scan item for packing** | ❌ | ✅ | ❌ | N/A | N/A | N/A |
| **Weight/dimension capture** | ❌ | ⚡ | ❌ | N/A | N/A | ⚡ |
| **Print receipt at completion** | ❌ | ✅ | ❌ | N/A | N/A | ✅ |
| **Auto-post shipment + invoice** | ❌ | ✅ | ❌ | N/A | N/A | ✅ |
| **Packing history** | ❌ | ⚡ | ❌ | ✅ | N/A | ✅ |

### 3. RECEIVING (Goods inbound)

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Warehouse receipts list** | ❌ | ❌ | ✅ | ✅ | N/A | ✅ |
| **Scan receipt no.** | ❌ | ❌ | ✅ | N/A | N/A | N/A |
| **Scan item + quantity** | ❌ | ❌ | ✅ | N/A | N/A | N/A |
| **Lot/Serial capture** | ❌ | ❌ | ✅ | N/A | N/A | N/A |
| **Bin assignment** | ❌ | ❌ | ✅ | N/A | N/A | ⚡ |
| **Quality hold flag** | ❌ | ❌ | ✅ | N/A | N/A | ✅ |
| **Register receipt** | ❌ | ❌ | ✅ | N/A | N/A | ✅ |
| **Over-receipt detection** | ❌ | ❌ | ✅ | N/A | N/A | ✅ |

### 4. PUTAWAY (Stocking materials)

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Putaway order list** | ❌ | ❌ | ✅ | ✅ | N/A | ✅ |
| **Scan LP/item + bin** | ❌ | ❌ | ✅ | N/A | N/A | N/A |
| **Directed putaway** | ❌ | ❌ | ✅ | N/A | N/A | ✅ |
| **Manual bin override** | ❌ | ❌ | ✅ | N/A | N/A | ✅ |
| **Register putaway** | ❌ | ❌ | ✅ | N/A | N/A | ✅ |

### 5. SHIPPING (Outbound coordination)

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Sales order list** | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ |
| **Shipment list** | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ |
| **Create shipment** | ❌ | ✅ | ❌ | ✅ | N/A | ✅ |
| **Post shipment + invoice** | ❌ | ✅ | ❌ | N/A | N/A | ✅ |
| **Print BOL/label** | ❌ | ✅ | ❌ | N/A | N/A | ✅ |
| **Carrier integration** | ❌ | ⚡ | ❌ | N/A | N/A | ⚡ |

### 6. QUALITY & INSPECTION

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Quality order list** | ⚡ | ✅ | ⚡ | ✅ | N/A | ✅ |
| **Manual QC create** | ⚡ | ✅ | ⚡ | ✅ | N/A | ✅ |
| **Inspection checklist** | ⚡ | ✅ | ⚡ | N/A | N/A | ✅ |
| **Pass/Fail/Hold decision** | ⚡ | ✅ | ⚡ | N/A | N/A | ✅ |
| **MS Quality Mgmt integration** | ⚡ | ✅ | ⚡ | ✅ | N/A | ✅ |

### 7. COUNTS & INVENTORY

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Cycle count list** | ⚡ | ❌ | ⚡ | ✅ | N/A | ✅ |
| **Scan bin + item + qty** | ⚡ | ❌ | ⚡ | N/A | N/A | N/A |
| **Variance detection** | ⚡ | ❌ | ⚡ | N/A | N/A | ✅ |
| **Register count** | ⚡ | ❌ | ⚡ | N/A | N/A | ✅ |
| **Directed move** | ⚡ | ❌ | ⚡ | N/A | N/A | ⚡ |

**Note:** Count module is Phase 2 (coming soon in v1.11).

### 8. AD-HOC OPERATIONS

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Ad-Hoc move (LP-based)** | ✅ | ❌ | ⚡ | ✅ | N/A | ✅ |
| **Item-based move** | ✅ | ❌ | ⚡ | ✅ | N/A | ✅ |
| **Lot tracking on move** | ✅ | ❌ | ⚡ | N/A | N/A | ✅ |
| **Bin transfer** | ✅ | ❌ | ⚡ | N/A | N/A | ✅ |
| **LP consolidation** | ✅ | ❌ | ⚡ | N/A | N/A | ✅ |

### 9. PRODUCTION & ASSEMBLY

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Consumption report** | ⚡ | ❌ | ❌ | ✅ | N/A | ✅ |
| **Output report** | ⚡ | ❌ | ❌ | ✅ | N/A | ⚡ |
| **Assembly kit check** | ⚡ | ❌ | ❌ | ✅ | N/A | ⚡ |

**Note:** Production/Assembly features are Phase 2 (limited functionality).

### 10. MANAGEMENT & REPORTING

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Dashboard (tiles)** | N/A | N/A | N/A | ✅ | ✅ | ⚡ |
| **PickBoard (visual Kanban)** | N/A | N/A | N/A | ✅ | ✅ | N/A |
| **Multi-pick creation** | N/A | N/A | N/A | ✅ | ✅ | ⚡ |
| **Task assignment** | N/A | N/A | N/A | ✅ | ✅ | ✅ |
| **Activity audit log** | N/A | N/A | N/A | ✅ | N/A | ✅ |
| **Performance reports** | N/A | N/A | N/A | ⚡ | ⚡ | ⚡ |
| **User time tracking** | N/A | N/A | N/A | ⚡ | N/A | ✅ |

### 11. USER MANAGEMENT

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **Local user provisioning** | N/A | N/A | N/A | ⚡ | N/A | ✅ |
| **Role assignment** | N/A | N/A | N/A | ✅ | N/A | ✅ |
| **Password reset** | N/A | N/A | N/A | ✅ | N/A | ✅ |
| **Multi-company access** | ✅ | ✅ | ✅ | ✅ | N/A | ✅ |
| **Login audit trail** | ✅ | ✅ | ✅ | ✅ | N/A | ✅ |

### 12. SYSTEM UTILITIES

| Feature | Picker | Packer | Receiver | Manager | OpsConsole | BC Native |
|---------|--------|--------|----------|---------|------------|-----------|
| **License plate (LP) library** | ✅ | ❌ | ⚡ | ✅ | ✅ | ✅ |
| **Item inquiry** | ✅ | ⚡ | ✅ | ✅ | N/A | ✅ |
| **Bin inquiry** | ✅ | ❌ | ✅ | ✅ | N/A | ✅ |
| **Warehouse entries** | ❌ | ❌ | ⚡ | ✅ | N/A | ✅ |
| **Printer management** | ⚡ | ✅ | ⚡ | ✅ | N/A | ✅ |
| **Field settings** | ✅ | ✅ | ✅ | N/A | N/A | N/A |
| **System health check** | N/A | N/A | N/A | N/A | N/A | ✅ |

---

## Platform-Specific Notes

### Terminal (Android)
- **Authentication:** AAD (Azure AD) or local WMS user
- **Network:** Requires live API connection (offline queue planned for v1.11)
- **UI:** Material Design 3, gesture-optimized for handheld
- **Locales:** en-US, tr-TR, de-DE
- **Min API:** Android 8.0 (API 26)
- **Current Build:** versionCode 1114, versionName 1.10.14

### OpsConsole (Web)
- **Deployment:** BC control add-in (default) or SaaS PWA (`BCWMS_TARGET=saas`)
- **Framework:** React 19, Vite 5, TypeScript 5.6
- **Responsive:** Tablet/mobile optimized (768px breakpoint)
- **Dark mode:** Supported via CSS media queries
- **Locales:** en-US, tr-TR

### BC Native
- **Platform:** Business Central 24.0+
- **Extension:** DynOps WMS (DOPSWHS prefix, 72000-72499 object range)
- **AL Language:** AL (Dynamics 365 Business Central AL)
- **Publishing:** Requires Windows sandbox environment (cannot compile on macOS)

---

## Version Roadmap

| Version | Status | Release Target | Major Features |
|---------|--------|-----------------|-----------------|
| **1.10.0** | ✅ GA | June 2026 | Multi-pick, 3 pack modes, tote/LP assignment, audit log |
| **1.11.0** | 📋 Planned | Q3 2026 | Offline queue, Count module, batch actions, reporting |
| **1.12.0** | 📋 Planned | Q4 2026 | Production/Assembly, advanced license enforcement |

---

## Support Matrix

| Component | Support | Contact |
|-----------|---------|---------|
| Terminal crashes | ⚠️ Beta | SDK support portal |
| WMS login issues | ✅ Full | support@dynops.com |
| BC publish errors | ⚠️ Windows only | DynOps AL team |
| Feature requests | 📋 Backlog | feedback@dynops.com |

---

## Glossary

- **LP:** License Plate — reusable shipping container (tote/pallet) or carton
- **Tote:** Persistent bin/container for multi-order picking
- **Multi-pick:** Single warehouse activity covering multiple sales orders
- **Directed pick:** System recommends bin sequence for efficient walk path
- **Short-pick:** Partial fulfillment when item qty unavailable
- **QC hold:** Goods flagged for inspection before release to shipment
- **Audit log:** Real-time record of operator actions (scan, assign, complete)

---

**For onboarding instructions,** see [wms-end-user-quickstart.md](wms-end-user-quickstart.md).  
**For deployment checklist,** see [install-pte.md](install-pte.md).
