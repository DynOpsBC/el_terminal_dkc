# Sprint 3 Release Notes

Sprint 3 adds receiving support across Business Central AL and Android.

## Added

- Warehouse Receipt, Purchase Order, and Transfer Order page extensions for mobile receiving actions.
- Receipt API v2.0 with receipt lines and bound actions for assign, start LP, stop LP, and post.
- Receipt management codeunit wrapping standard warehouse receipt posting and linking LPs to posted receipt lines.
- Legacy WI compatibility publisher codeunit for receipt, purchase, and transfer document events.
- Receiving Queue ListPart with assigned user and completion percentage.
- AL receipt posting, LP receiving, and end-to-end receive test codeunits.
- Android `:feature-receive` screens, MVI ViewModel, repository, and Hilt module.
- Android receipt entities, receipt use cases, and core-sync queue operations for receipt confirmations and LP receiving actions.

## Notes

The AL compiler was not run in this environment. `PostReceipt` remains online-only on Android; queueable receiving mutations are line confirmation, receipt assignment, start LP, and stop LP.
