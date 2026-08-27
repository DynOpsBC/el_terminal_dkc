page 72224 "DOPSWHS Assembly API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'assembly';
    EntitySetName = 'assemblies';
    SourceTable = "Assembly Header";
    SourceTableView = where(Status = const(Released));
    DelayedInsert = true;
    ODataKeyFields = "Document Type", "No.";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; }
                field(documentType; Rec."Document Type") { Caption = 'documentType'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; }
                field(remainingQuantity; Rec."Remaining Quantity") { Caption = 'remainingQuantity'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                field(dueDate; Rec."Due Date") { Caption = 'dueDate'; }
                field(assembleToOrder; Rec."Assemble to Order") { Caption = 'assembleToOrder'; }
                part(lines; "DOPSWHS Assembly Line API")
                {
                    Caption = 'lines';
                    EntityName = 'assemblyLine';
                    EntitySetName = 'assemblyLines';
                    SubPageLink = "Document Type" = field("Document Type"), "Document No." = field("No.");
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::Assembly);
        RecRef.SetTable(Rec);
    end;

    [ServiceEnabled]
    procedure post()
    var
        AssemblyMgmt: Codeunit "DOPSWHS Assembly Mgmt";
    begin
        AssemblyMgmt.PostAssembly(Rec);
    end;
}
