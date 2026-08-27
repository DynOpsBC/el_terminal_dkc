page 72089 "DOPSWHS LP Line API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'licensePlateLine';
    EntitySetName = 'licensePlateLines';
    SourceTable = "DOPSWHS LP Line";
    DelayedInsert = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    ODataKeyFields = "LP No.", "Line No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(lpNo; Rec."LP No.") { Caption = 'lpNo'; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; }
                field(unitOfMeasure; Rec."Unit of Measure") { Caption = 'unitOfMeasure'; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; }
                field(lotNo; Rec."Lot No.") { Caption = 'lotNo'; }
                field(serialNo; Rec."Serial No.") { Caption = 'serialNo'; }
                field(packageNo; Rec."Package No.") { Caption = 'packageNo'; }
                field(childLpNo; Rec."Child LP No.") { Caption = 'childLpNo'; }
                field(expirationDate; Rec."Expiration Date") { Caption = 'expirationDate'; }
                field(sourceBinCode; Rec."Source Bin Code") { Caption = 'sourceBinCode'; }
                field(sourceDocumentType; Rec."Source Document Type") { Caption = 'sourceDocumentType'; }
                field(sourceDocumentNo; Rec."Source Document No.") { Caption = 'sourceDocumentNo'; }
            }
        }
    }
    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::LicensePlateLine);
        RecRef.SetTable(Rec);
    end;

}
