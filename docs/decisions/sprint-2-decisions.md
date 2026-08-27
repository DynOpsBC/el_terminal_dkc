# Sprint 2 Decisions

## License Plate Bin Content Rollup

Implemented in `al/src/LicensePlate/BinContentSubscriber.Codeunit.al`, codeunit `72039 "DOPSWHS Bin Content Subscriber"`.

The current implementation exposes `CalculateNestedLPQuantity(LocationCode, BinCode, ItemNo)` and recursively walks only root LPs in the target bin (`Parent LP No.` = blank), then sums leaf item lines through `SumLeafItemLines`. This avoids multiplying parent container counts by child contents. The intended Business Central hook point remains the bin content calculation extension point, but the code in this sprint is a callable rollup helper rather than a compiled `[EventSubscriber]` to an `OnAfterCalcBinContent` publisher.

## Number Series

LP numbers use `DOPSWHS Setup"."LP No. Series"`. Tests seed the confirmed setup code `LP`.

SSCC numbers use `DOPSWHS Setup"."SSCC No. Series"`. Tests seed the confirmed setup code `SSCC`.

## SSCC Generation

`al/src/LicensePlate/SSCCGenerator.Codeunit.al` uses GS1 Company Prefix plus a digits-only serial reference from the SSCC number series, then calculates the GS1 mod-10 check digit. If the GS1 Company Prefix is empty, the generator uses filler prefix `9999999` and logs `SSCC.ExtensionPrefix`.

## IWX Report Selection Usage

`al/src/Print/IWXReportUsage.Enum.al` is an extensible enum, not an option field. Final values are `LpLabel`, `Receipt`, `Pick`, `Ship`, `Item`, `Bin`, `PostedShipment`, `Custom1`, `Custom2`, and `Custom3`. Enum was chosen to keep report usage extension-safe for partner verticals.

## LP Template Seeds

`al/src/Setup/SetupWizard.Codeunit.al` seeds four templates:

- `CARTON-S`: 30 x 20 x 15 cm, max 15 kg
- `CARTON-M`: 40 x 30 x 20 cm, max 25 kg
- `PALLET-EUR`: 120 x 80 x 120 cm, max 1000 kg
- `TOTE-A`: 50 x 35 x 30 cm, max 30 kg

## ZPL Builder

`android/core-printer/src/main/java/com/dynops/bcwms/printer/ZplBuilder.kt` uses a focused string-template builder rather than a DSL. The label emits `^XA`, Code 128 SSCC barcode with `^BC`, location/bin text, top-five item summary by quantity, LP number, timestamp, and `^XZ`.

## Print Channel

`al/src/Setup/PrintChannel.Enum.al` final values are `PrintNode = 0` and `BCNative = 1`. Device configuration defaults to `BCNative`; setup supports either value. No conflicting Android enum was introduced in Sprint 2.

## Deviations

Android repository calls are endpoint-shaped stubs built from `BcApiClient.barcodeParseUrl()` because expanding `BcApiClient` was outside the focused gap-fill file list.

Sync LP operation handlers are explicit dispatcher branches in `SyncWorker.handleOp()` and currently return success placeholders until Sprint 3 wires the durable queue transport.
