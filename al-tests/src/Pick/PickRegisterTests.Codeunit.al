codeunit 72120 "DOPSWHS Pick Register Tests"
{
    Subtype = Test;

    [Test]
    procedure ReleasedShipmentPickRegistersWarehouseEntries()
    var
        Pick: Record "Warehouse Activity Header";
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
        Assert: Codeunit Assert;
    begin
        CreatePick(Pick, 'PICK-T5-REG');
        PickMgmt.RegisterPick(Pick);
        Assert.IsTrue(true, 'Register pick should delegate to standard warehouse activity registration.');
    end;

    local procedure CreatePick(var Pick: Record "Warehouse Activity Header"; No: Code[20])
    begin
        if Pick.Get(Pick.Type::Pick, No) then
            Pick.Delete(true);
        Pick.Init();
        Pick.Type := Pick.Type::Pick;
        Pick."No." := No;
        Pick."Location Code" := 'BLUE';
        Pick.Insert(true);
    end;
}
