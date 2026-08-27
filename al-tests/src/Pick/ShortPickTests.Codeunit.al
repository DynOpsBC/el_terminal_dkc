codeunit 72123 "DOPSWHS Short Pick Tests"
{
    Subtype = Test;

    [Test]
    procedure MarkShortWithReasonAllowsRegister()
    var
        Line: Record "Warehouse Activity Line";
        Reason: Record "DOPSWHS Short Pick Reason";
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
        Assert: Codeunit Assert;
    begin
        EnsureReason(Reason);
        Line.Init();
        Line."Activity Type" := Line."Activity Type"::Pick;
        Line."No." := 'PICK-T5-SHORT';
        Line."Line No." := 10000;
        Line.Quantity := 5;
        Line.Insert(true);
        PickMgmt.RegisterShortPick(Line, 2, Reason."Code");
        Assert.AreEqual(2, Line."Qty. to Handle", 'Short quantity must be the quantity to handle.');
        Assert.IsTrue(Reason."Allows Backorder", 'NO_STOCK keeps the standard backorder path enabled.');
    end;

    local procedure EnsureReason(var Reason: Record "DOPSWHS Short Pick Reason")
    begin
        if Reason.Get('NO_STOCK') then exit;
        Reason.Init(); Reason."Code" := 'NO_STOCK'; Reason.Description := 'No stock'; Reason.Default := true; Reason."Allows Backorder" := true; Reason.Insert(true);
    end;
}
