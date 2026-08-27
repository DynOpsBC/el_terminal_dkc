page 72088 "DOPSWHS LP API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'licensePlate';
    EntitySetName = 'licensePlates';
    SourceTable = "DOPSWHS LP Header";
    DelayedInsert = true;
    DeleteAllowed = true;
    ODataKeyFields = "No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(parentLpNo; Rec."Parent LP No.") { Caption = 'parentLpNo'; }
                field(templateCode; Rec."LP Template Code") { Caption = 'templateCode'; }
                field(reusable; Reusable) { Caption = 'reusable'; Editable = false; }
                field(sscc; Rec.SSCC) { Caption = 'sscc'; }
                field(assignedDocumentType; Rec."Assigned Document Type") { Caption = 'assignedDocumentType'; }
                field(assignedDocumentNo; Rec."Assigned Document No.") { Caption = 'assignedDocumentNo'; }
                field(weightKg; Rec."Weight kg") { Caption = 'weightKg'; }
                field(lengthCm; Rec."Length cm") { Caption = 'lengthCm'; }
                field(widthCm; Rec."Width cm") { Caption = 'widthCm'; }
                field(heightCm; Rec."Height cm") { Caption = 'heightCm'; }
                field(notes; Rec.Notes) { Caption = 'notes'; }
                field(lineCount; Rec."Line Count") { Caption = 'lineCount'; Editable = false; }
                field(totalQuantity; Rec."Total Quantity") { Caption = 'totalQuantity'; Editable = false; }
                field(unitType; Rec."Unit Type") { Caption = 'unitType'; Editable = false; }
                field(hierarchicalLpEnabled; HierarchicalLpEnabled) { Caption = 'hierarchicalLpEnabled'; Editable = false; }
                field(hierarchyLabelPrintCount; Rec."Hierarchy Label Print Count") { Caption = 'hierarchyLabelPrintCount'; Editable = false; }
                field(hierarchyLabelPrintedAt; Rec."Hierarchy Label Printed At") { Caption = 'hierarchyLabelPrintedAt'; Editable = false; }
            }
            part(lines; "DOPSWHS LP Line API")
            {
                Caption = 'lines';
                EntityName = 'licensePlateLine';
                EntitySetName = 'licensePlateLines';
                SubPageLink = "LP No." = field("No.");
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::LicensePlate);
        RecRef.SetTable(Rec);
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
        CreatedLP: Record "DOPSWHS LP Header";
    begin
        // API POST doğrudan tablo insert'i yaparsa şablon ölçüleri ve Built
        // hareket kaydı atlanır. Tüm LP oluşturma kanallarını tek iş kuralına bağla.
        LPMgt.Build(Rec."LP Template Code", Rec."Location Code", Rec."Bin Code", CreatedLP);
        Rec := CreatedLP;
        exit(false);
    end;

    trigger OnAfterGetRecord()
    var
        Template: Record "DOPSWHS LP Template";
        Setup: Record "DOPSWHS Setup";
    begin
        Rec.CalcFields("Line Count", "Total Quantity");
        Reusable := false;
        if (Rec."LP Template Code" <> '') and Template.Get(Rec."LP Template Code") then
            Reusable := Template.Reusable;
        HierarchicalLpEnabled := Setup.Get('') and Setup."Hierarchical LP Enabled";
    end;

    var
        Reusable: Boolean;
        HierarchicalLpEnabled: Boolean;

    [ServiceEnabled]
    procedure release()
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Release(Rec);
    end;

    [ServiceEnabled]
    procedure assign(docType: Enum "DOPSWHS Assigned Doc Type"; docNo: Code[20])
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Assign(Rec, docType, docNo);
    end;

    [ServiceEnabled]
    procedure unbuild()
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Unbuild(Rec);
    end;

    [ServiceEnabled]
    procedure transfer(targetLpNo: Code[20]; linesJson: Text)
    var
        TargetLP: Record "DOPSWHS LP Header";
        SourceLine: Record "DOPSWHS LP Line";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Lines: List of [Integer];
        Quantities: Dictionary of [Integer, Decimal];
    begin
        TargetLP.Get(targetLpNo);
        ParseLines(linesJson, Lines, Quantities);
        // Boş linesJson = "tüm içerik": önceden sessizce hiçbir satır
        // taşınmıyordu (boş liste boş döngü) — tüm satırlarla doldur.
        if Lines.Count() = 0 then begin
            SourceLine.SetRange("LP No.", Rec."No.");
            if SourceLine.FindSet() then
                repeat
                    Lines.Add(SourceLine."Line No.");
                until SourceLine.Next() = 0;
        end;
        LPMgt.Transfer(Rec, TargetLP, Lines, Quantities);
    end;

    [ServiceEnabled]
    procedure usePartial(action: Text; qty: Decimal; lineNo: Integer)
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
        PartialAction: Enum "DOPSWHS Partial Use Action";
    begin
        case UpperCase(DelChr(action, '=', ' _-')) of
            'CREATENEWLP':
                PartialAction := PartialAction::CreateNewLP;
            'REMOVEEXCESS':
                PartialAction := PartialAction::RemoveExcess;
            'REMOVEUSEDPORTION':
                PartialAction := PartialAction::RemoveUsedPortion;
            'UNBUILD':
                PartialAction := PartialAction::Unbuild;
            else
                Error('Geçersiz kısmi kullanım işlemi: %1.', action);
        end;
        LPMgt.SplitForPartialUse(Rec, PartialAction, qty, lineNo);
    end;

    [ServiceEnabled]
    procedure printLabel(printerId: Code[50]; copies: Integer)
    var
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
    begin
        Dispatcher.PrintLPLabel(Rec, printerId, copies);
    end;

    [ServiceEnabled]
    procedure printDocument(printerId: Code[50]; copies: Integer): Integer
    var
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
    begin
        exit(Dispatcher.PrintLPDocument(Rec, printerId, copies));
    end;

    [ServiceEnabled]
    procedure nest(parentLpNo: Code[20])
    var
        ParentLP: Record "DOPSWHS LP Header";
        NestManager: Codeunit "DOPSWHS LP Nest Manager";
    begin
        ParentLP.Get(parentLpNo);
        NestManager.Nest(Rec, ParentLP);
    end;

    [ServiceEnabled]
    procedure unnest()
    var
        NestManager: Codeunit "DOPSWHS LP Nest Manager";
    begin
        NestManager.Unnest(Rec);
    end;

    // DKC/EMU hierarchy actions are deliberately separate from the legacy
    // nest/unnest endpoints. Existing BADE clients retain their current LP
    // contract, while these actions fail closed unless enabled per company.
    [ServiceEnabled]
    procedure completeHierarchyNode()
    var
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
    begin
        HierarchyMgt.CompleteNode(Rec);
        Rec.Get(Rec."No.");
    end;

    [ServiceEnabled]
    procedure attachChild(childLpNo: Code[20])
    var
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
    begin
        HierarchyMgt.AttachChild(Rec, childLpNo);
        Rec.Get(Rec."No.");
    end;

    [ServiceEnabled]
    procedure detachChild(childLpNo: Code[20])
    var
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
    begin
        HierarchyMgt.DetachChild(Rec, childLpNo);
        Rec.Get(Rec."No.");
    end;

    [ServiceEnabled]
    procedure getHierarchy(): Text
    var
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
    begin
        exit(HierarchyMgt.GetHierarchyJson(Rec));
    end;

    [ServiceEnabled]
    procedure moveHierarchy(targetBinCode: Code[20]; userId: Code[50])
    var
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
    begin
        HierarchyMgt.MoveHierarchy(Rec, targetBinCode, userId);
        Rec.Get(Rec."No.");
    end;

    [ServiceEnabled]
    procedure completeAndPrint(printerId: Code[50]; labelProfile: Code[20]; copies: Integer)
    var
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
    begin
        HierarchyMgt.CompleteAndPrint(Rec, printerId, labelProfile, copies);
        Rec.Get(Rec."No.");
    end;

    [ServiceEnabled]
    procedure reprintHierarchyLabel(printerId: Code[50]; labelProfile: Code[20]; copies: Integer; reason: Text[100])
    var
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
    begin
        HierarchyMgt.ReprintLabel(Rec, printerId, labelProfile, copies, reason);
        Rec.Get(Rec."No.");
    end;

    [ServiceEnabled]
    procedure start(templateCode: Code[20]; locationCode: Code[10]; binCode: Code[20])
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
        NewLP: Record "DOPSWHS LP Header";
    begin
        LPMgt.Build(templateCode, locationCode, binCode, NewLP);
        Rec.Get(NewLP."No.");
    end;

    [ServiceEnabled]
    procedure addLineFromBin(itemNo: Code[20]; unitOfMeasure: Code[10]; quantity: Decimal; lotNo: Code[50]; serialNo: Code[50]; sourceBinCode: Code[20]; userId: Code[50])
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.AddLineFromBin(Rec, itemNo, unitOfMeasure, quantity, lotNo, serialNo, sourceBinCode, userId);
    end;

    [ServiceEnabled]
    procedure moveToBin(targetBinCode: Code[20]; userId: Code[50])
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.MoveToBin(Rec, targetBinCode, userId);
        Rec.Get(Rec."No.");
    end;

    [ServiceEnabled]
    procedure stop(printLabel: Boolean)
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Stop(Rec, printLabel);
    end;

    [ServiceEnabled]
    procedure stopToPrinter(printLabel: Boolean; printerId: Code[50])
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        // LP completion is the primary warehouse transaction. Printing is
        // best-effort and must not roll the LP back to Open when a printer is
        // missing/offline or the print channel is temporarily unavailable.
        LPMgt.Stop(Rec, false);
        if printLabel then begin
            ClearLastError();
            if not TryPrintLabels(Rec, printerId) then
                Telemetry.LogWarning(
                    'Print.LPLabelFailed',
                    CopyStr(
                        StrSubstNo(
                            'LP %1 completed, but its combined MTE/LP label could not be printed: %2',
                            Rec."No.", GetLastErrorText()),
                        1, 250),
                    '');
        end;
    end;

    [TryFunction]
    local procedure TryPrintLabels(var LP: Record "DOPSWHS LP Header"; PrinterId: Code[50])
    var
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
    begin
        Dispatcher.PrintPalletItemLabels(LP, PrinterId, 1);
    end;

    local procedure ParseLines(LinesJson: Text; var Lines: List of [Integer]; var Quantities: Dictionary of [Integer, Decimal])
    var
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        JsonObject: JsonObject;
        LineToken: JsonToken;
        QtyToken: JsonToken;
        LineNo: Integer;
        Qty: Decimal;
    begin
        if LinesJson = '' then
            exit;
        JsonArray.ReadFrom(LinesJson);
        foreach JsonToken in JsonArray do begin
            JsonObject := JsonToken.AsObject();
            JsonObject.Get('lineNo', LineToken);
            Evaluate(LineNo, Format(LineToken.AsValue()));
            Lines.Add(LineNo);
            if JsonObject.Get('qty', QtyToken) then begin
                Evaluate(Qty, Format(QtyToken.AsValue()));
                Quantities.Add(LineNo, Qty);
            end;
        end;
    end;
}
