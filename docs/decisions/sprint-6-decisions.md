# Sprint 6 Decisions

## Shipment Queue

Chose a `SourceTable = Integer` virtual record pattern for the shipment queue because Business Central has no native multi-table list page over Warehouse Shipment, Sales Header, and Transfer Header. Tradeoff: standard sorting/filtering is not available across the combined queue.

## Android ViewModel

Chose a single `ShipViewModel` with a `SourceType` discriminator over three separate ViewModels. This reduces code surface for shared list, line, and posting state, but requires careful state isolation whenever the selected source type changes.

## SSCC Timing

Chose a pre-post hook for SSCC generation instead of relying on the LP Stop fallback. SSCC is committed before warehouse posting, avoiding posted shipment lines without SSCC if a later partial failure occurs.

## Ship & Invoice Order

Sales `Ship & Invoice` sets ship and invoice posting flags in the same posting transaction. If invoicing fails, standard Business Central error handling rolls back the transaction, avoiding partial commit risk.

## IWX Report Selection Seed

Seeded `IWX Report Selection` with `Posted Shipment` usage and Report ID `7321` as the default Posted Whse. Shipment report. The row is configurable after install.

## feature-ship Gradle

Added `core-domain` and `core-sync` module dependencies to `feature-ship`, matching the feature-move pattern and enabling shared shipment use cases plus sync queue operation types.
