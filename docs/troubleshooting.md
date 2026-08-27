# BCWMSApp Troubleshooting

1. Pick does not appear in mobile: confirm the pick is released, assigned to the user/device, and the location filter matches the device profile.
2. LP build fails with SSCC duplicate: check the SSCC No. Series and verify no sandbox data was copied into production numbering.
3. Bin not found when scanning: confirm the barcode rule maps to bin lookup and the scanned alias exists for the location.
4. Login loops after Entra sign-in: verify the tenant ID, redirect URI, and user permission set.
5. Camera opens but does not scan: check camera permission, lens focus, barcode symbology, and lighting.
6. Device says offline while WiFi works: verify the BC base URL, environment name, and firewall/proxy access.
7. Receipt cannot be posted: confirm the warehouse receipt is released and source purchase or transfer order is open.
8. Put-away suggests the wrong bin: review directed put-away strategy, fixed bins, and item/bin capacity.
9. Short pick reason is required: select a configured reason or ask a supervisor to add one.
10. Shipment pack action fails: confirm all required picks are registered and LP contents match the shipment lines.
11. Movement confirm fails: verify source bin quantity, destination bin existence, and item tracking.
12. Count line is locked: another assigned counter is editing or the sheet is in recount review.
13. Count posting blocked by variance: resolve recount-required lines and supervisor approval.
14. Production consumption fails: check released production order status, component availability, and bin.
15. Production output fails: verify routing/output setup, item tracking, and output quantity.
16. Assembly posting fails: confirm assembly order status, component availability, and quantity to assemble.
17. Item inquiry shows stale quantity: sync the device and refresh after Business Central posting completes.
18. Barcode parse returns unknown: add or correct the GS1/application identifier mapping rule.
19. Push notification missing: check notification permission, device registration, and push relay health.
20. Offline sync creates conflict: open Sync Conflict List, compare source document status, then retry or reject.
21. Printer does not receive output: for the recommended path confirm Print Channel=`AzureDirect`, the Windows agent says `Connected / Listening`, its Station ID matches BC, and the discovered printer is `Active/Online`. Check **Print Job Queue** (`Queued → Dispatched → Sent/Failed`), the Service Bus active/DLQ counts, and the agent log using the same Job ID. Select a ZPL printer as the terminal's **Etiket** default and a PDF printer as **Belge** default. First prove both devices with the agent's local tests, then run the cloud smoke test in [azure-direct-print-setup.md](azure-direct-print-setup.md). `Sent` means the Windows spooler accepted the job; inspect the physical printer for paper/toner/jam failures.
22. User can view but not post: assign DOPSWHS User or Admin permission set rather than View.
23. App is slow after launch: update to v1.0 build, clear local cache only after sync is complete, and check API latency dashboard.
24. German or Turkish label missing: verify the latest extension is installed and translation files are enabled.
