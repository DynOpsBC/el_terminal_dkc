# Sprint 2 Release Notes

Sprint 2 adds the license plate foundation across Business Central AL and Android.

## Added

- License plate core AL coverage: build, stop, reopen, partial use, nesting, SSCC generation, bin content rollup, and transfer test codeunits.
- Print infrastructure coverage: SSCC generation tests and Android ZPL builder for LP labels with Code 128 SSCC barcode, location/bin, item summary, LP number, and timestamp.
- Critical bin content rollup tests, including nested pallet/carton/tote scenarios that verify leaf quantities are counted once.
- Android `:feature-lp` screens for LP lookup, document view, build modal, partial-use bottom sheet, transfer, and properties.
- Android LP MVI ViewModel, repository endpoint stubs, Hilt module, core-domain LP entities, and LP use case wrappers.
- Android `:core-sync` LP operation models and dispatcher cases for build, stop, line add/remove, assign, unbuild, transfer, print, partial use, nest, and unnest.

## Notes

The AL compiler was not run in this environment. Sprint 3 receiving work should wire real API transport calls behind the Android repository and sync operation handlers.
