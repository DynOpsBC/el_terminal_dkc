codeunit 72051 "DOPSWHS Print Dispatcher"
{
    Access = Public;

    procedure PrintLPLabel(var LP: Record "DOPSWHS LP Header"; PrinterId: Code[50]; Copies: Integer)
    var
        Setup: Record "DOPSWHS Setup";
        Queue: Record "DOPSWHS Print Job Queue";
        LabelReport: Report "DOPSWHS LP Label";
        PrintNode: Codeunit "DOPSWHS PrintNode Client";
        SelfHosted: Codeunit "DOPSWHS Self-Host Print Client";
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
        TempBlob: Codeunit "Temp Blob";
        ZplInStream: InStream;
        OutStream: OutStream;
        Zpl: Text;
        ResolvedPrinter: Code[20];
        JobId: Integer;
    begin
        if Copies > 10 then
            Error('A print job cannot exceed 10 copies.');
        Setup.Get('');
        Zpl := LabelReport.BuildZpl(LP);

        if Setup."Print Channel" in [Setup."Print Channel"::SelfHosted, Setup."Print Channel"::AzureDirect] then begin
            GuardLicense().GuardFeature(Enum::"DOPSWHS License Feature"::PrintBridge);
            ResolvedPrinter := ResolveSelfHostedPrinter(PrinterId, Enum::"DOPSWHS IWX Report Usage"::LpLabel, Copies);
            if ResolvedPrinter = '' then
                Error('No WMS bridge printer is mapped for LP label printing. Configure Device Printer Mapping or pass a Printer Code.');
            if Setup."Print Channel" = Setup."Print Channel"::AzureDirect then begin
                TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
                OutStream.WriteText(Zpl);
                TempBlob.CreateInStream(ZplInStream);
                JobId := SelfHosted.EnqueueStreamForImmediateDispatch(
                    LP."No.",
                    Report::"DOPSWHS LP Label",
                    ResolvedPrinter,
                    Enum::"DOPSWHS Print Format"::ZPL,
                    ZplInStream,
                    Copies,
                    '');
                // The LP button is an explicit operator action: persist the job,
                // dispatch it now, and leave the recurring worker as recovery.
                Commit();
                AzureBridge.DispatchJob(JobId);
                Commit();
                Queue.Get(JobId);
                if Queue.Status in [Queue.Status::Queued, Queue.Status::Failed] then
                    Error('The LP label job was saved but Azure dispatch failed: %1', Queue."Last Error");
            end else
                SelfHosted.Enqueue(LP."No.", ResolvedPrinter, Enum::"DOPSWHS Print Format"::ZPL, Zpl, Copies);
            exit;
        end;
        if Setup."Print Channel" = Setup."Print Channel"::BCNative then begin
            if not GuiAllowed() then
                Error('Business Central Native cannot deliver a terminal ZPL label. Configure Azure Direct, Self-Hosted or PrintNode.');
        end else
            if Setup."Print Channel" <> Setup."Print Channel"::PrintNode then
                Error('Print channel %1 is not supported for LP labels.', Setup."Print Channel");
        if Copies <= 0 then
            Copies := 1;

        Queue.Init();
        Queue."Source Doc" := LP."No.";
        Queue."Report ID" := Report::"DOPSWHS LP Label";
        Queue."Printer ID" := PrinterId;
        Queue.Channel := Setup."Print Channel";
        Queue."Format" := Enum::"DOPSWHS Print Format"::ZPL;
        Queue.Copies := Copies;
        Queue.Status := Queue.Status::Queued;
        Queue.Created := CurrentDateTime();
        Queue.ZPL.CreateOutStream(OutStream);
        OutStream.WriteText(Zpl);
        Queue.Insert(true);
        if Setup."Print Channel" = Setup."Print Channel"::PrintNode then
            PrintNode.SendPrintJob(Queue, Copies)
        else begin
            Report.Run(Report::"DOPSWHS LP Label", false, false, LP);
            Queue.Status := Queue.Status::Sent;
            Queue.Sent := CurrentDateTime();
            Queue.Modify(true);
        end;
    end;

    procedure PrintItemLabel(var Item: Record Item; PrinterId: Code[50]; Copies: Integer)
    begin
        EnqueueZpl(Item."No.", BuildItemZpl(Item), PrinterId, Copies, Enum::"DOPSWHS IWX Report Usage"::Item, 'Item');
    end;

    /// <summary>
    /// Prints one material-identification label for every item line on an LP.
    /// The same physical LP printer is used so the existing mobile request and
    /// printer selection remain unchanged.
    /// </summary>
    procedure PrintPalletItemLabels(var LP: Record "DOPSWHS LP Header"; PrinterId: Code[50]; Copies: Integer)
    var
        LPLine: Record "DOPSWHS LP Line";
        LabelLine: Record "DOPSWHS LP Line";
        PrintedGroups: Dictionary of [Text, Boolean];
        GroupKey: Text;
    begin
        LPLine.SetRange("LP No.", LP."No.");
        LPLine.SetFilter("Item No.", '<>%1', '');
        if LPLine.FindSet() then
            repeat
                GroupKey := PalletItemGroupKey(LPLine);
                if not PrintedGroups.ContainsKey(GroupKey) then begin
                    PrintedGroups.Add(GroupKey, true);
                    LabelLine := LPLine;
                    LabelLine.Quantity := PalletItemGroupQuantity(LPLine);
                    EnqueueZpl(
                        LP."No.",
                        BuildPalletItemZpl(LP, LabelLine),
                        PrinterId,
                        Copies,
                        Enum::"DOPSWHS IWX Report Usage"::LpLabel,
                        'LP material identification');
                end;
            until LPLine.Next() = 0;
    end;

    /// <summary>
    /// Prints the EMU/DKC hierarchy label selected by the server-side LP unit
    /// type. The profile code is kept explicit so a box can never accidentally
    /// receive a pallet/SSCC label.
    /// </summary>
    procedure PrintDkcHierarchyLabel(var LP: Record "DOPSWHS LP Header"; LabelProfile: Code[20]; PrinterId: Code[50]; Copies: Integer)
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') or not Setup."Hierarchical LP Enabled" then
            Error('Hierarchical LP is not enabled for this Business Central company.');
        EnqueueZpl(
            LP."No.",
            BuildDkcHierarchyZpl(LP, LabelProfile),
            PrinterId,
            Copies,
            Enum::"DOPSWHS IWX Report Usage"::LpLabel,
            'DKC hierarchy');
    end;

    procedure BuildDkcHierarchyZpl(var LP: Record "DOPSWHS LP Header"; LabelProfile: Code[20]): Text
    var
        ZplEncoder: Codeunit "DOPSWHS ZPL Encoder";
        ItemNo: Code[20];
        LotNo: Code[50];
        TotalQuantity: Decimal;
        DirectChildCount: Integer;
        LeafCount: Integer;
        MixedItems: Boolean;
        MixedLots: Boolean;
        ItemText: Text;
        LotText: Text;
        BarcodeZpl: Text;
        FooterZpl: Text;
        LotInitialized: Boolean;
    begin
        CollectDkcLabelSummary(LP, ItemNo, LotNo, TotalQuantity, LeafCount, MixedItems, MixedLots, LotInitialized, 0);
        DirectChildCount := CountDirectChildren(LP);
        if MixedItems then
            ItemText := 'KARMA'
        else
            ItemText := ItemNo;
        if MixedLots then
            LotText := 'KARMA'
        else
            LotText := LotNo;

        if UpperCase(LabelProfile) = 'DKC-PALLET' then begin
            if StrLen(LP.SSCC) <> 18 then
                Error('%1 pallet must have an 18-digit SSCC before label printing.', LP."No.");
            // ZPL Code 128 invocation: >; selects Code Set C and >8 inserts
            // FNC1, producing GS1-128 Application Identifier 00 + SSCC-18.
            BarcodeZpl := '^FO35,238^BY2^BCN,105,Y,N,N^FH_^FD>;>800' + ZplEncoder.EncodeFieldData(LP.SSCC) + '^FS';
        end else
            BarcodeZpl := '^FO575,80^BQN,2,6^FH_^FDLA,' + ZplEncoder.EncodeFieldData(LP."No.") + '^FS';
        if UpperCase(LabelProfile) = 'DKC-PALLET' then
            FooterZpl := '^FO35,370^A0N,20,20^FH_^FD(00) ' + LP.SSCC + '^FS'
        else
            FooterZpl := '^FO35,350^BY2^BCN,38,N,N,N^FH_^FD' + ZplEncoder.EncodeFieldData(LP."No.") + '^FS';

        exit(
            '^XA^CI28^PW812^LL406' +
            '^FO35,18^A0N,34,34^FH_^FD' + ZplEncoder.EncodeFieldData(UpperCase(LabelProfile)) + '^FS' +
            '^FO35,62^A0N,31,31^FH_^FDLP: ' + ZplEncoder.EncodeFieldData(LP."No.") + '^FS' +
            '^FO35,104^A0N,23,23^FH_^FDTUR: ' + ZplEncoder.EncodeFieldData(Format(LP."Unit Type")) + '^FS' +
            '^FO35,140^A0N,23,23^FH_^FDMADDE: ' + ZplEncoder.EncodeFieldData(CopyStr(ItemText, 1, 24)) + '^FS' +
            '^FO35,176^A0N,23,23^FH_^FDLOT: ' + ZplEncoder.EncodeFieldData(CopyStr(LotText, 1, 28)) + '^FS' +
            '^FO35,212^A0N,23,23^FH_^FDMKT: ' + ZplEncoder.EncodeFieldData(Format(TotalQuantity)) + '  ALT LP: ' + Format(LeafCount) + '^FS' +
            BarcodeZpl +
            '^FO575,320^A0N,19,19^FH_^FDDOGRUDAN ALT: ' + Format(DirectChildCount) + '^FS' +
            FooterZpl +
            '^XZ');
    end;

    local procedure CollectDkcLabelSummary(LP: Record "DOPSWHS LP Header"; var ItemNo: Code[20]; var LotNo: Code[50]; var TotalQuantity: Decimal; var LeafCount: Integer; var MixedItems: Boolean; var MixedLots: Boolean; var LotInitialized: Boolean; Depth: Integer)
    var
        Setup: Record "DOPSWHS Setup";
        LPLine: Record "DOPSWHS LP Line";
        ChildLP: Record "DOPSWHS LP Header";
    begin
        Setup.Get('');
        if Depth > Setup."Max LP Nesting Depth" then
            Error('LP hierarchy depth exceeds the configured maximum of %1.', Setup."Max LP Nesting Depth");
        LPLine.SetRange("LP No.", LP."No.");
        LPLine.SetFilter("Item No.", '<>%1', '');
        if LPLine.FindSet() then begin
            LeafCount += 1;
            repeat
                TotalQuantity += LPLine.Quantity;
                if ItemNo = '' then
                    ItemNo := LPLine."Item No."
                else
                    if ItemNo <> LPLine."Item No." then
                        MixedItems := true;
                if not LotInitialized then begin
                    LotNo := LPLine."Lot No.";
                    LotInitialized := true;
                end else
                    if LotNo <> LPLine."Lot No." then
                        MixedLots := true;
            until LPLine.Next() = 0;
        end;
        ChildLP.SetRange("Parent LP No.", LP."No.");
        if ChildLP.FindSet() then
            repeat
                CollectDkcLabelSummary(ChildLP, ItemNo, LotNo, TotalQuantity, LeafCount, MixedItems, MixedLots, LotInitialized, Depth + 1);
            until ChildLP.Next() = 0;
    end;

    local procedure CountDirectChildren(LP: Record "DOPSWHS LP Header"): Integer
    var
        ChildLP: Record "DOPSWHS LP Header";
    begin
        ChildLP.SetRange("Parent LP No.", LP."No.");
        exit(ChildLP.Count());
    end;

    procedure BuildPalletItemZpl(var LP: Record "DOPSWHS LP Header"; var LPLine: Record "DOPSWHS LP Line"): Text
    var
        Item: Record Item;
        ZplEncoder: Codeunit "DOPSWHS ZPL Encoder";
        DescriptionText: Text;
        TotalQuantity: Decimal;
        QrData: Text;
        TotalText: Text;
        PalletText: Text;
        LotText: Text;
    begin
        if Item.Get(LPLine."Item No.") then
            DescriptionText := Item.Description;
        TotalQuantity := LPLine."Source Document Quantity";
        if TotalQuantity = 0 then
            TotalQuantity := LPLine.Quantity;

        TotalText := StrSubstNo('TOPLAM MAL KABUL: %1 %2', TotalQuantity, LPLine."Unit of Measure");
        PalletText := StrSubstNo('PALET MIKTARI: %1 %2', LPLine.Quantity, LPLine."Unit of Measure");
        if LPLine."Lot No." <> '' then
            LotText := 'LOT: ' + LPLine."Lot No.";

        // A pallet-bound MTE is the single physical label for both identities:
        // scan the LP when present, otherwise preserve the lot/item fallback.
        QrData := LP."No.";
        if QrData = '' then
            QrData := LPLine."Lot No.";
        if QrData = '' then
            QrData := LPLine."Item No.";

        exit(
            '^XA^CI28^PW812^LL406' +
            '^FO35,18^A0N,28,28^FH_^FDMADDE TANIMLAMA ETIKETI^FS' +
            '^FO35,62^A0N,28,28^FH_^FDMADDE: ' + ZplEncoder.EncodeFieldData(CopyStr(LPLine."Item No.", 1, 18)) + '^FS' +
            '^FO35,104^A0N,21,21^FH_^FD' + ZplEncoder.EncodeFieldData(CopyStr(DescriptionText, 1, 24)) + '^FS' +
            '^FO35,142^A0N,24,24^FH_^FD' + ZplEncoder.EncodeFieldData(CopyStr(LotText, 1, 20)) + '^FS' +
            '^FO35,182^A0N,24,24^FH_^FDLP: ' + ZplEncoder.EncodeFieldData(LP."No.") + '^FS' +
            '^FO35,232^A0N,26,26^FH_^FD' + ZplEncoder.EncodeFieldData(CopyStr(TotalText, 1, 48)) + '^FS' +
            '^FO35,282^A0N,36,36^FH_^FD' + ZplEncoder.EncodeFieldData(CopyStr(PalletText, 1, 42)) + '^FS' +
            '^FO610,58^BQN,2,5^FH_^FDLA,' + ZplEncoder.EncodeFieldData(QrData) + '^FS' +
            '^XZ');
    end;

    local procedure PalletItemGroupKey(LPLine: Record "DOPSWHS LP Line"): Text
    begin
        exit(
            LPLine."Item No." + '|' + LPLine."Variant Code" + '|' + LPLine."Unit of Measure" + '|' +
            LPLine."Lot No." + '|' + LPLine."Serial No." + '|' + Format(LPLine."Source Document Type") + '|' +
            LPLine."Source Document No." + '|' + Format(LPLine."Source Document Line No."));
    end;

    local procedure PalletItemGroupQuantity(LPLine: Record "DOPSWHS LP Line"): Decimal
    var
        GroupLine: Record "DOPSWHS LP Line";
        GroupQuantity: Decimal;
    begin
        GroupLine.SetRange("LP No.", LPLine."LP No.");
        GroupLine.SetRange("Item No.", LPLine."Item No.");
        GroupLine.SetRange("Variant Code", LPLine."Variant Code");
        GroupLine.SetRange("Unit of Measure", LPLine."Unit of Measure");
        GroupLine.SetRange("Lot No.", LPLine."Lot No.");
        GroupLine.SetRange("Serial No.", LPLine."Serial No.");
        GroupLine.SetRange("Source Document Type", LPLine."Source Document Type");
        GroupLine.SetRange("Source Document No.", LPLine."Source Document No.");
        GroupLine.SetRange("Source Document Line No.", LPLine."Source Document Line No.");
        if GroupLine.FindSet() then
            repeat
                GroupQuantity += GroupLine.Quantity;
            until GroupLine.Next() = 0;
        exit(GroupQuantity);
    end;

    procedure PrintBinLabel(var Bin: Record Bin; PrinterId: Code[50]; Copies: Integer)
    begin
        EnqueueZpl(Bin."Code", BuildBinZpl(Bin), PrinterId, Copies, Enum::"DOPSWHS IWX Report Usage"::Bin, 'Bin');
    end;

    /// <summary>
    /// Renders the exact value scanned by a terminal as a one-page PDF and
    /// sends it to the explicitly selected document printer. This deliberately
    /// does not parse GS1/LP/item prefixes: the test output must prove which raw
    /// value reached Business Central from the scanner.
    /// </summary>
    procedure PrintBarcodeTest(PrinterId: Code[50]; BarcodeValue: Text; Copies: Integer): Integer
    var
        BarcodeReport: Report "DOPSWHS Barcode Print Test";
        TempBlob: Codeunit "Temp Blob";
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
        SelfHosted: Codeunit "DOPSWHS Self-Host Print Client";
        Setup: Record "DOPSWHS Setup";
        Queue: Record "DOPSWHS Print Job Queue";
        PdfInStream: InStream;
        PdfOutStream: OutStream;
        CleanValue: Text;
        Position: Integer;
        CharacterNumber: Integer;
        JobId: Integer;
    begin
        CleanValue := BarcodeValue.Trim();
        if CleanValue = '' then
            Error('Scan a barcode before starting the print test.');
        if StrLen(CleanValue) > 48 then
            Error('The scanned barcode cannot exceed 48 characters in the printable Code 128 test.');
        for Position := 1 to StrLen(CleanValue) do begin
            CharacterNumber := CleanValue[Position];
            if (CharacterNumber < 32) or (CharacterNumber = 127) then
                Error('The scanned barcode contains an unsupported control character.');
            if CharacterNumber > 126 then
                Error('The printable Code 128 test supports standard ASCII characters only.');
        end;
        if Copies <= 0 then
            Copies := 1;
        if Copies > 10 then
            Error('A print job cannot exceed 10 copies.');

        EnsureDocumentPrinter(PrinterId, Enum::"DOPSWHS IWX Report Usage"::Receipt);
        BarcodeReport.SetBarcodeValue(CleanValue);
        TempBlob.CreateOutStream(PdfOutStream);
        if not BarcodeReport.SaveAs('', ReportFormat::Pdf, PdfOutStream) then
            Error('The scanned barcode test PDF could not be rendered.');
        if not TempBlob.HasValue() then
            Error('The scanned barcode test produced an empty PDF.');
        Setup.Get('');
        TempBlob.CreateInStream(PdfInStream);
        if Setup."Print Channel" = Setup."Print Channel"::AzureDirect then
            JobId := SelfHosted.EnqueueStreamForImmediateDispatch(
                'BARCODE-TEST',
                Report::"DOPSWHS Barcode Print Test",
                CopyStr(PrinterId, 1, 20),
                Enum::"DOPSWHS Print Format"::PDF,
                PdfInStream,
                Copies,
                '')
        else
            JobId := EnqueuePdf('BARCODE-TEST', Report::"DOPSWHS Barcode Print Test", PrinterId, Copies, Enum::"DOPSWHS IWX Report Usage"::Receipt, PdfInStream);

        // This is an explicit terminal test action. Commit its durable audit row
        // and dispatch it in the same request so the operator does not have to
        // wait for the one-minute recovery worker or press Validate Azure Print.
        // The recurring worker remains the retry/recovery path for failures.
        if Setup."Print Channel" = Setup."Print Channel"::AzureDirect then begin
            Commit();
            AzureBridge.DispatchJob(JobId);
            Commit();
            Queue.Get(JobId);
            if Queue.Status in [Queue.Status::Queued, Queue.Status::Failed] then
                Error('The barcode print job was saved but Azure dispatch failed: %1', Queue."Last Error");
        end;
        exit(JobId);
    end;

    /// <summary>
    /// Creates an A4 PDF containing the LP number as a QR code and immediately
    /// dispatches it to the selected PDF/document printer.
    /// </summary>
    procedure PrintLPDocument(var LP: Record "DOPSWHS LP Header"; PrinterId: Code[50]; Copies: Integer): Integer
    var
        LpQrReport: Report "DOPSWHS LP QR Document";
        TempBlob: Codeunit "Temp Blob";
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
        SelfHosted: Codeunit "DOPSWHS Self-Host Print Client";
        Setup: Record "DOPSWHS Setup";
        Queue: Record "DOPSWHS Print Job Queue";
        PdfInStream: InStream;
        PdfOutStream: OutStream;
        ResolvedPrinter: Code[20];
        JobId: Integer;
    begin
        if Copies <= 0 then
            Copies := 1;
        if Copies > 10 then
            Error('A print job cannot exceed 10 copies.');

        ResolvedPrinter := ResolveSelfHostedPrinter(PrinterId, Enum::"DOPSWHS IWX Report Usage"::Receipt, Copies);
        if ResolvedPrinter = '' then
            Error('No PDF document printer is selected for LP QR printing.');
        EnsureDocumentPrinter(ResolvedPrinter, Enum::"DOPSWHS IWX Report Usage"::Receipt);

        LP.SetRecFilter();
        LpQrReport.SetTableView(LP);
        TempBlob.CreateOutStream(PdfOutStream);
        if not LpQrReport.SaveAs('', ReportFormat::Pdf, PdfOutStream) then
            Error('The LP QR PDF could not be rendered.');
        if not TempBlob.HasValue() then
            Error('The LP QR report produced an empty PDF.');

        Setup.Get('');
        TempBlob.CreateInStream(PdfInStream);
        if Setup."Print Channel" = Setup."Print Channel"::AzureDirect then
            JobId := SelfHosted.EnqueueStreamForImmediateDispatch(
                LP."No.",
                Report::"DOPSWHS LP QR Document",
                ResolvedPrinter,
                Enum::"DOPSWHS Print Format"::PDF,
                PdfInStream,
                Copies,
                '')
        else
            JobId := EnqueuePdf(LP."No.", Report::"DOPSWHS LP QR Document", ResolvedPrinter, Copies, Enum::"DOPSWHS IWX Report Usage"::Receipt, PdfInStream);

        if Setup."Print Channel" = Setup."Print Channel"::AzureDirect then begin
            Commit();
            AzureBridge.DispatchJob(JobId);
            Commit();
            Queue.Get(JobId);
            if Queue.Status in [Queue.Status::Queued, Queue.Status::Failed] then
                Error('The LP QR print job was saved but Azure dispatch failed: %1', Queue."Last Error");
        end;
        exit(JobId);
    end;

    // Item/Bin etiketleri için LP-label ile aynı kanal mantığı; içerik satır-içi
    // ZPL (ayrı Report objesine gerek yok). PrintNode ZPL blob'unu kullanır.
    local procedure EnqueueZpl(SourceDoc: Code[50]; Zpl: Text; PrinterId: Code[50]; Copies: Integer; Usage: Enum "DOPSWHS IWX Report Usage"; LabelName: Text)
    var
        Setup: Record "DOPSWHS Setup";
        Queue: Record "DOPSWHS Print Job Queue";
        PrintNode: Codeunit "DOPSWHS PrintNode Client";
        SelfHosted: Codeunit "DOPSWHS Self-Host Print Client";
        OutStream: OutStream;
        ResolvedPrinter: Code[20];
    begin
        if Copies > 10 then
            Error('A print job cannot exceed 10 copies.');
        Setup.Get('');

        if Setup."Print Channel" in [Setup."Print Channel"::SelfHosted, Setup."Print Channel"::AzureDirect] then begin
            GuardLicense().GuardFeature(Enum::"DOPSWHS License Feature"::PrintBridge);
            ResolvedPrinter := ResolveSelfHostedPrinter(PrinterId, Usage, Copies);
            if ResolvedPrinter = '' then
                Error('No WMS bridge printer is mapped for %1 label printing. Configure Device Printer Mapping or pass a Printer Code.', LabelName);
            SelfHosted.Enqueue(SourceDoc, ResolvedPrinter, Enum::"DOPSWHS Print Format"::ZPL, Zpl, Copies);
            exit;
        end;
        if Setup."Print Channel" <> Setup."Print Channel"::PrintNode then
            Error('Inline %1 ZPL labels require Azure Direct, Self-Hosted or PrintNode; Business Central Native has no physical ZPL route.', LabelName);
        if Copies <= 0 then
            Copies := 1;

        Queue.Init();
        Queue."Source Doc" := SourceDoc;
        Queue."Printer ID" := PrinterId;
        Queue.Channel := Setup."Print Channel";
        Queue."Format" := Enum::"DOPSWHS Print Format"::ZPL;
        Queue.Copies := Copies;
        Queue.Status := Queue.Status::Queued;
        Queue.Created := CurrentDateTime();
        Queue.ZPL.CreateOutStream(OutStream);
        OutStream.WriteText(Zpl);
        Queue.Insert(true);
        PrintNode.SendPrintJob(Queue, Copies);
    end;

    local procedure BuildItemZpl(var Item: Record Item): Text
    var
        ZplEncoder: Codeunit "DOPSWHS ZPL Encoder";
    begin
        exit(
            '^XA^CI28^PW812^LL406' +
            '^FO40,30^A0N,40,40^FH_^FD' + ZplEncoder.EncodeFieldData(Item."No.") + '^FS' +
            '^FO40,80^A0N,28,28^FH_^FD' + ZplEncoder.EncodeFieldData(CopyStr(Item.Description, 1, 42)) + '^FS' +
            '^FO40,130^BY2^BCN,110,Y,N,N^FH_^FD' + ZplEncoder.EncodeFieldData(Item."No.") + '^FS' +
            '^XZ');
    end;

    local procedure BuildBinZpl(var Bin: Record Bin): Text
    var
        ZplEncoder: Codeunit "DOPSWHS ZPL Encoder";
    begin
        exit(
            '^XA^CI28^PW812^LL406' +
            '^FO40,30^A0N,40,40^FH_^FD' + ZplEncoder.EncodeFieldData(Bin."Location Code" + ' / ' + Bin.Code) + '^FS' +
            '^FO40,90^BY2^BCN,120,Y,N,N^FH_^FD' + ZplEncoder.EncodeFieldData(Bin.Code) + '^FS' +
            '^XZ');
    end;

    /// <summary>
    /// Renders a filtered Business Central report as PDF and routes it through
    /// the same provider queue used by terminal labels. The RecordRef is
    /// mandatory so a report can never accidentally print every record.
    /// </summary>
    procedure PrintReport(SourceDoc: Code[50]; ReportId: Integer; PrinterId: Code[50]; Copies: Integer; Usage: Enum "DOPSWHS IWX Report Usage"; SourceRecord: RecordRef): Integer
    var
        TempBlob: Codeunit "Temp Blob";
        PdfInStream: InStream;
        PdfOutStream: OutStream;
    begin
        if ReportId = 0 then
            Error('A report must be configured for print usage %1.', Usage);
        if SourceRecord.Number() = 0 then
            Error('A source record is required to render report %1.', ReportId);
        if Copies > 10 then
            Error('A print job cannot exceed 10 copies.');

        EnsureDocumentPrinter(PrinterId, Usage);

        TempBlob.CreateOutStream(PdfOutStream);
        if not Report.SaveAs(ReportId, '', ReportFormat::Pdf, PdfOutStream, SourceRecord) then
            Error('Report %1 could not be rendered as PDF.', ReportId);
        if not TempBlob.HasValue() then
            Error('Report %1 produced an empty PDF.', ReportId);
        TempBlob.CreateInStream(PdfInStream);
        exit(EnqueuePdf(SourceDoc, ReportId, PrinterId, Copies, Usage, PdfInStream));
    end;

    procedure EnsureDocumentPrinter(PrinterId: Code[50]; Usage: Enum "DOPSWHS IWX Report Usage")
    var
        Setup: Record "DOPSWHS Setup";
        Printer: Record "DOPSWHS Printer";
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
        ResolvedPrinter: Code[20];
        EffectiveCopies: Integer;
    begin
        if not Setup.Get('') then
            Error('Advanced WMS Setup must be configured before document printing.');
        case Setup."Print Channel" of
            Setup."Print Channel"::SelfHosted,
            Setup."Print Channel"::AzureDirect:
                begin
                    GuardLicense().GuardFeature(Enum::"DOPSWHS License Feature"::PrintBridge);
                    ResolvedPrinter := ResolveSelfHostedPrinter(PrinterId, Usage, EffectiveCopies);
                    if ResolvedPrinter = '' then
                        Error('No WMS bridge printer is mapped for %1. Select a document printer or configure Device Printer Mapping.', Usage);
                    Printer.Get(ResolvedPrinter);
                    if Printer."Format" <> Printer."Format"::PDF then
                        Error('Printer %1 is configured for %2. %3 document printing requires a PDF printer.', ResolvedPrinter, Printer."Format", Usage);
                    if Setup."Print Channel" = Setup."Print Channel"::AzureDirect then
                        AzureBridge.ValidateAzurePrinter(Printer);
                end;
            Setup."Print Channel"::PrintNode:
                if PrinterId = '' then
                    Error('A PrintNode printer ID is required for %1 document printing.', Usage);
            else
                Error('Terminal document printing requires Azure Direct, Self-Hosted or PrintNode. BC Native cannot route an API-session PDF to a physical printer.');
        end;
    end;

    procedure IsDocumentPrinterConfigured(PrinterId: Code[50]; Usage: Enum "DOPSWHS IWX Report Usage"): Boolean
    var
        Setup: Record "DOPSWHS Setup";
        Printer: Record "DOPSWHS Printer";
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
        ResolvedPrinter: Code[20];
    begin
        if not Setup.Get('') then
            exit(false);
        case Setup."Print Channel" of
            Setup."Print Channel"::SelfHosted,
            Setup."Print Channel"::AzureDirect:
                begin
                    ResolvedPrinter := ResolveConfiguredSelfHostedPrinter(PrinterId, Usage);
                    if ResolvedPrinter = '' then
                        exit(false);
                    if not Printer.Get(ResolvedPrinter) then
                        exit(false);
                    if Printer."Format" <> Printer."Format"::PDF then
                        exit(false);
                    if Setup."Print Channel" = Setup."Print Channel"::AzureDirect then begin
                        if not AzureBridge.TryValidateAzurePrinter(Printer) then begin
                            ClearLastError();
                            exit(false);
                        end;
                    end;
                    exit(true);
                end;
            Setup."Print Channel"::PrintNode:
                exit(PrinterId <> '');
            else
                exit(false);
        end;
    end;

    [Obsolete('Use PrintReport with a filtered RecordRef and explicit usage/printer.', '1.13')]
    procedure QueueReport(SourceDoc: Code[50]; ReportId: Integer)
    begin
        Error('QueueReport can no longer create an unfiltered, empty print job. Use PrintReport with a filtered RecordRef.');
    end;

    local procedure EnqueuePdf(SourceDoc: Code[50]; ReportId: Integer; PrinterId: Code[50]; Copies: Integer; Usage: Enum "DOPSWHS IWX Report Usage"; PdfStream: InStream): Integer
    var
        Setup: Record "DOPSWHS Setup";
        SelfHosted: Codeunit "DOPSWHS Self-Host Print Client";
        ResolvedPrinter: Code[20];
    begin
        Setup.Get('');
        case Setup."Print Channel" of
            Setup."Print Channel"::SelfHosted,
            Setup."Print Channel"::AzureDirect:
                begin
                    GuardLicense().GuardFeature(Enum::"DOPSWHS License Feature"::PrintBridge);
                    ResolvedPrinter := ResolveSelfHostedPrinter(PrinterId, Usage, Copies);
                    if ResolvedPrinter = '' then
                        Error('No WMS bridge printer is mapped for %1. Configure Device Printer Mapping or pass a Printer Code.', Usage);
                    exit(SelfHosted.EnqueueStream(SourceDoc, ReportId, ResolvedPrinter, Enum::"DOPSWHS Print Format"::PDF, PdfStream, Copies, ''));
                end;
            Setup."Print Channel"::PrintNode:
                begin
                    if Copies <= 0 then
                        Copies := 1;
                    exit(EnqueuePrintNodePdf(SourceDoc, ReportId, PrinterId, Copies, PdfStream));
                end;
            else
                Error('Terminal document printing requires Azure Direct, Self-Hosted or PrintNode. BC Native cannot route an API-session PDF to a physical printer.');
        end;
    end;

    local procedure EnqueuePrintNodePdf(SourceDoc: Code[50]; ReportId: Integer; PrinterId: Code[50]; Copies: Integer; PdfStream: InStream): Integer
    var
        Queue: Record "DOPSWHS Print Job Queue";
        PrintNode: Codeunit "DOPSWHS PrintNode Client";
        TempBlob: Codeunit "Temp Blob";
        BufferInStream: InStream;
        BufferOutStream: OutStream;
        QueueOutStream: OutStream;
    begin
        if PrinterId = '' then
            Error('A PrintNode printer ID is required for document printing.');
        TempBlob.CreateOutStream(BufferOutStream);
        CopyStream(BufferOutStream, PdfStream);
        if not TempBlob.HasValue() then
            Error('The PDF print payload is empty.');

        Queue.Init();
        Queue."Source Doc" := SourceDoc;
        Queue."Report ID" := ReportId;
        Queue."Printer ID" := PrinterId;
        Queue.Channel := Queue.Channel::PrintNode;
        Queue."Format" := Enum::"DOPSWHS Print Format"::PDF;
        Queue.Copies := Copies;
        Queue.Status := Queue.Status::Queued;
        Queue.Created := CurrentDateTime();
        Queue."Payload Size" := TempBlob.Length();
        TempBlob.CreateInStream(BufferInStream);
        Queue.ZPL.CreateOutStream(QueueOutStream);
        CopyStream(QueueOutStream, BufferInStream);
        Queue.Insert(true);
        PrintNode.SendPrintJob(Queue, Copies);
        exit(Queue."Job ID");
    end;

    local procedure GuardLicense(): Codeunit "DOPSWHS License Mgmt"
    var
        License: Codeunit "DOPSWHS License Mgmt";
    begin
        exit(License);
    end;

    local procedure ResolveSelfHostedPrinter(Candidate: Code[50]; Usage: Enum "DOPSWHS IWX Report Usage"; var Copies: Integer): Code[20]
    var
        Printer: Record "DOPSWHS Printer";
        SelfHosted: Codeunit "DOPSWHS Self-Host Print Client";
        ResolvedCode: Code[20];
        RequestedCopies: Integer;
    begin
        if Candidate <> '' then begin
            if StrLen(Candidate) > MaxStrLen(Printer."Code") then
                Error('Printer code %1 exceeds the supported length.', Candidate);
            if not Printer.Get(CopyStr(Candidate, 1, MaxStrLen(Printer."Code"))) then
                Error('Printer %1 is not registered.', Candidate);
            if not Printer.Active then
                Error('Printer %1 is inactive.', Candidate);
            if Copies <= 0 then
                Copies := Printer."Default Copies";
            if Copies <= 0 then
                Copies := 1;
            if Copies > 10 then
                Error('A print job cannot exceed 10 copies.');
            exit(Printer."Code");
        end;
        RequestedCopies := Copies;
        if not SelfHosted.ResolvePrinterAndCopies(CopyStr(UserId(), 1, 50), Usage, RequestedCopies, ResolvedCode, Copies) then
            exit('');
        exit(ResolvedCode);
    end;

    local procedure ResolveConfiguredSelfHostedPrinter(Candidate: Code[50]; Usage: Enum "DOPSWHS IWX Report Usage"): Code[20]
    var
        Printer: Record "DOPSWHS Printer";
        SelfHosted: Codeunit "DOPSWHS Self-Host Print Client";
        ResolvedCode: Code[20];
    begin
        if Candidate <> '' then begin
            if StrLen(Candidate) > MaxStrLen(Printer."Code") then
                exit('');
            ResolvedCode := CopyStr(Candidate, 1, MaxStrLen(Printer."Code"));
        end else
            ResolvedCode := SelfHosted.ResolvePrinter(CopyStr(UserId(), 1, 50), Usage);
        if (ResolvedCode = '') or (not Printer.Get(ResolvedCode)) or (not Printer.Active) then
            exit('');
        exit(ResolvedCode);
    end;
}
