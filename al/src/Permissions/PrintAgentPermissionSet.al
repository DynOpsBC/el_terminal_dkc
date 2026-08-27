permissionset 72369 "DOPSWHS-PRINT-AGENT"
{
    Assignable = true;
    Caption = 'Advanced WMS Print Agent';

    Permissions =
        tabledata "DOPSWHS Print Job Queue" = RM,
        tabledata "DOPSWHS Print Job Log" = RI,
        tabledata "DOPSWHS Printer" = RM,
        table "DOPSWHS Print Job Queue" = X,
        table "DOPSWHS Print Job Log" = X,
        table "DOPSWHS Printer" = X,
        page "DOPSWHS Print Job API" = X,
        page "DOPSWHS Printer Agent API" = X,
        codeunit "DOPSWHS Self-Host Print Client" = X;
}
