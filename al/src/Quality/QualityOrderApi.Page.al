page 72256 "DOPSWHS Quality Order API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'qualityOrder';
    EntitySetName = 'qualityOrders';
    SourceTable = "DOPSWHS Quality Order";
    DelayedInsert = true;
    ODataKeyFields = "No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; }
                field(sourceType; Rec."Source Type") { Caption = 'sourceType'; }
                field(sourceNo; Rec."Source No.") { Caption = 'sourceNo'; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                field(itemDescription; Rec."Item Description") { Caption = 'itemDescription'; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; }
                field(sampleSize; Rec."Sample Size") { Caption = 'sampleSize'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                field(lpNo; Rec."LP No.") { Caption = 'lpNo'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(inspector; Rec.Inspector) { Caption = 'inspector'; }
                field(inspectedDateTime; Rec."Inspected DateTime") { Caption = 'inspectedDateTime'; }
                field(resultNotes; Rec."Result Notes") { Caption = 'resultNotes'; }
                field(rejectReason; Rec."Reject Reason") { Caption = 'rejectReason'; }
                field(quarantineBin; Rec."Quarantine Bin") { Caption = 'quarantineBin'; }
                field(dueDate; Rec."Due Date") { Caption = 'dueDate'; }
            }
        }
    }

    /// <summary>Records a PASS result on this quality order.</summary>
    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::QualityOrder);
        RecRef.SetTable(Rec);
    end;

    [ServiceEnabled]
    procedure pass(inspector: Code[50]; notes: Text[250])
    var
        QualityMgmt: Codeunit "DOPSWHS Quality Mgmt";
    begin
        QualityMgmt.Pass(Rec, inspector, notes);
    end;

    /// <summary>Records a FAIL result with a reason; routes goods to a quarantine bin.</summary>
    [ServiceEnabled]
    procedure fail(inspector: Code[50]; reasonCode: Code[20]; notes: Text[250]; quarantineBin: Code[20])
    var
        QualityMgmt: Codeunit "DOPSWHS Quality Mgmt";
    begin
        QualityMgmt.Fail(Rec, inspector, reasonCode, notes, quarantineBin);
    end;

    /// <summary>Creates a new quality order (bound action so an unbound entry point isn't required).</summary>
    [ServiceEnabled]
    procedure createOrder(sourceType: Integer; sourceNo: Code[20]; itemNo: Code[20]; qty: Decimal; locationCode: Code[10]; binCode: Code[20]; lpNo: Code[20]): Code[20]
    var
        QualityMgmt: Codeunit "DOPSWHS Quality Mgmt";
    begin
        exit(QualityMgmt.CreateOrder(sourceType, sourceNo, itemNo, qty, locationCode, binCode, lpNo));
    end;
}
