using Microsoft.Foundation.Reporting;

codeunit 72367 "DOPSWHS BC Printer Provider"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::ReportManagement, 'OnAfterSetupPrinters', '', true, true)]
    local procedure RegisterWmsPrinters(var Printers: Dictionary of [Text[250], JsonObject])
    var
        Setup: Record "DOPSWHS Setup";
        Printer: Record "DOPSWHS Printer";
        PrinterPayload: JsonObject;
        PaperTrays: JsonArray;
        DefaultTray: JsonObject;
        VirtualPrinterName: Text[250];
    begin
        if not Setup.Get('') then
            exit;
        if not (Setup."Print Channel" in [Setup."Print Channel"::SelfHosted, Setup."Print Channel"::AzureDirect]) then
            exit;

        Printer.SetRange(Active, true);
        Printer.SetRange("Enable BC Reports", true);
        Printer.SetRange("Format", Printer."Format"::PDF);
        if not Printer.FindSet() then
            exit;

        repeat
            if IsReadyForChannel(Setup, Printer) then begin
                Clear(PrinterPayload);
                Clear(PaperTrays);
                Clear(DefaultTray);

                PrinterPayload.Add('version', 1);
                if Printer.Description <> '' then
                    PrinterPayload.Add('description', Printer.Description)
                else
                    PrinterPayload.Add('description', StrSubstNo('DynOps WMS printer %1', Printer."Code"));

                if (Printer."Paper Width (mm)" > 0) and (Printer."Paper Height (mm)" > 0) then begin
                    DefaultTray.Add('papersourcekind', 'Custom');
                    DefaultTray.Add('paperkind', 'Custom');
                    DefaultTray.Add('units', 'MM');
                    DefaultTray.Add('width', Printer."Paper Width (mm)");
                    DefaultTray.Add('height', Printer."Paper Height (mm)");
                end else begin
                    DefaultTray.Add('papersourcekind', 'Upper');
                    DefaultTray.Add('paperkind', 'A4');
                end;

                PaperTrays.Add(DefaultTray);
                PrinterPayload.Add('papertrays', PaperTrays);
                VirtualPrinterName := GetVirtualPrinterName(Printer."Code");
                if not Printers.ContainsKey(VirtualPrinterName) then
                    Printers.Add(VirtualPrinterName, PrinterPayload);
            end;
        until Printer.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::ReportManagement, 'OnAfterDocumentPrintReady', '', true, true)]
    local procedure EnqueueStandardBcReport(ObjectType: Option "Report","Page"; ObjectId: Integer; ObjectPayload: JsonObject; DocumentStream: InStream; var Success: Boolean)
    var
        Setup: Record "DOPSWHS Setup";
        Printer: Record "DOPSWHS Printer";
        SelfHosted: Codeunit "DOPSWHS Self-Host Print Client";
        PrinterName: Text;
        DocumentType: Text;
        ReportRunId: Text;
        SourceDoc: Code[50];
        PrinterCode: Code[20];
    begin
        if Success then
            exit;
        if ObjectType <> ObjectType::Report then
            exit;
        PrinterName := GetPayloadText(ObjectPayload, 'printername');
        if CopyStr(PrinterName, 1, StrLen(VirtualPrinterPrefixLbl)) <> VirtualPrinterPrefixLbl then
            exit;

        PrinterCode := CopyStr(DelStr(PrinterName, 1, StrLen(VirtualPrinterPrefixLbl)), 1, MaxStrLen(PrinterCode));
        if not Printer.Get(PrinterCode) then
            exit;
        if (not Printer.Active) or (not Printer."Enable BC Reports") or
           (Printer."Format" <> Printer."Format"::PDF)
        then
            exit;
        if not Setup.Get('') then
            exit;
        if not (Setup."Print Channel" in [Setup."Print Channel"::SelfHosted, Setup."Print Channel"::AzureDirect]) then
            exit;

        DocumentType := LowerCase(GetPayloadText(ObjectPayload, 'documenttype'));
        if (DocumentType <> '') and (DocumentType <> 'application/pdf') then
            Error('Business Central produced unsupported print content %1. PDF was expected.', DocumentType);

        GuardLicense().GuardFeature(Enum::"DOPSWHS License Feature"::PrintBridge);
        ReportRunId := GetPayloadText(ObjectPayload, 'reportrunid');
        if ReportRunId <> '' then
            SourceDoc := CopyStr(ReportRunId, 1, MaxStrLen(SourceDoc))
        else
            SourceDoc := CopyStr(StrSubstNo('REPORT-%1', ObjectId), 1, MaxStrLen(SourceDoc));

        SelfHosted.EnqueueStream(
            SourceDoc,
            ObjectId,
            PrinterCode,
            Enum::"DOPSWHS Print Format"::PDF,
            DocumentStream,
            1,
            CopyStr(ReportRunId, 1, 100));
        Success := true;
    end;

    procedure GetVirtualPrinterName(PrinterCode: Code[20]): Text[250]
    begin
        exit(CopyStr(VirtualPrinterPrefixLbl + PrinterCode, 1, 250));
    end;

    local procedure GetPayloadText(ObjectPayload: JsonObject; PropertyName: Text): Text
    var
        ValueToken: JsonToken;
    begin
        if not ObjectPayload.Get(PropertyName, ValueToken) then
            exit('');
        if not ValueToken.IsValue() then
            exit('');
        exit(ValueToken.AsValue().AsText());
    end;

    local procedure GuardLicense(): Codeunit "DOPSWHS License Mgmt"
    var
        License: Codeunit "DOPSWHS License Mgmt";
    begin
        exit(License);
    end;

    local procedure IsReadyForChannel(Setup: Record "DOPSWHS Setup"; Printer: Record "DOPSWHS Printer"): Boolean
    var
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
    begin
        if Setup."Print Channel" <> Setup."Print Channel"::AzureDirect then
            exit(true);
        if AzureBridge.TryValidateAzurePrinter(Printer) then
            exit(true);
        ClearLastError();
        exit(false);
    end;

    var
        VirtualPrinterPrefixLbl: Label 'DOPSWHS::', Locked = true;
}
