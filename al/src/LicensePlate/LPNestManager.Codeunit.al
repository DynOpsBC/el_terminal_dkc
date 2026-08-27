codeunit 72041 "DOPSWHS LP Nest Manager"
{
    Access = Public;

    procedure Nest(var ChildLP: Record "DOPSWHS LP Header"; var ParentLP: Record "DOPSWHS LP Header")
    var
        Setup: Record "DOPSWHS Setup";
        LPMgt: Codeunit "DOPSWHS LP Management";
        MaxDepth: Integer;
    begin
        if ChildLP."Location Code" <> ParentLP."Location Code" then
            Error('Nested LPs must be in the same location.');
        if ChildLP.Status in [ChildLP.Status::Open, ChildLP.Status::Assigned] then
            Error('Open or assigned LPs cannot be nested.');
        if ParentLP.Status in [ParentLP.Status::Open, ParentLP.Status::Assigned] then
            Error('Open or assigned LPs cannot receive nested LPs.');
        if WouldCreateCycle(ChildLP."No.", ParentLP."No.") then
            Error('Nested LP cycle detected.');

        MaxDepth := 3;
        if Setup.Get('') and (Setup."Max LP Nesting Depth" > 0) then
            MaxDepth := Setup."Max LP Nesting Depth";
        if GetNestingDepth(ParentLP) + 1 > MaxDepth then
            Error('LP nesting depth cannot exceed %1.', MaxDepth);

        ChildLP."Parent LP No." := ParentLP."No.";
        ChildLP.Modify(true);
        LPMgt.WriteToLedger(ChildLP, Enum::"DOPSWHS LP Action"::NestIn, ChildLP."Bin Code", ParentLP."Bin Code", 0, '', '', ParentLP."No.");
    end;

    procedure Unnest(var ChildLP: Record "DOPSWHS LP Header")
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
        ParentNo: Code[20];
    begin
        if ChildLP.Status = ChildLP.Status::Assigned then
            Error('Assigned LPs cannot be unnested.');
        ParentNo := ChildLP."Parent LP No.";
        ChildLP."Parent LP No." := '';
        ChildLP.Modify(true);
        LPMgt.WriteToLedger(ChildLP, Enum::"DOPSWHS LP Action"::Unnest, ChildLP."Bin Code", ChildLP."Bin Code", 0, '', '', ParentNo);
    end;

    procedure GetNestingDepth(LP: Record "DOPSWHS LP Header"): Integer
    var
        ParentLP: Record "DOPSWHS LP Header";
    begin
        if LP."Parent LP No." = '' then
            exit(0);
        if not ParentLP.Get(LP."Parent LP No.") then
            exit(0);
        exit(1 + GetNestingDepth(ParentLP));
    end;

    procedure GetRootLP(LP: Record "DOPSWHS LP Header"): Code[20]
    var
        ParentLP: Record "DOPSWHS LP Header";
    begin
        if LP."Parent LP No." = '' then
            exit(LP."No.");
        ParentLP.Get(LP."Parent LP No.");
        exit(GetRootLP(ParentLP));
    end;

    local procedure WouldCreateCycle(ChildNo: Code[20]; ParentNo: Code[20]): Boolean
    var
        ParentLP: Record "DOPSWHS LP Header";
    begin
        if ChildNo = ParentNo then
            exit(true);
        if ParentNo = '' then
            exit(false);
        if not ParentLP.Get(ParentNo) then
            exit(false);
        exit(WouldCreateCycle(ChildNo, ParentLP."Parent LP No."));
    end;
}
