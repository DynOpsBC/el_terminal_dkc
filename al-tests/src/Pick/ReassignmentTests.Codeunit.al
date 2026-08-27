codeunit 72122 "DOPSWHS Reassignment Tests"
{
    Subtype = Test;

    [Test]
    procedure ReassignWritesHistoryAndChangesUser()
    var
        Pick: Record "Warehouse Activity Header";
        History: Record "DOPSWHS Pick Reassign Hist";
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
        Assert: Codeunit Assert;
    begin
        CreatePick(Pick);
        PickMgmt.ReassignPick(Pick, 'NEWUSER', 'test');
        History.SetRange("Pick No.", Pick."No.");
        Assert.IsTrue(History.FindLast(), 'Reassignment history must be written.');
        Assert.AreEqual('OLDUSER', History."From User", 'Previous user must be captured.');
        Assert.AreEqual('NEWUSER', Pick."Assigned User ID", 'Pick must move to the new user.');
    end;

    local procedure CreatePick(var Pick: Record "Warehouse Activity Header")
    begin
        if Pick.Get(Pick.Type::Pick, 'PICK-T5-REAS') then Pick.Delete(true);
        Pick.Init(); Pick.Type := Pick.Type::Pick; Pick."No." := 'PICK-T5-REAS'; Pick."Location Code" := 'BLUE'; Pick."Assigned User ID" := 'OLDUSER'; Pick.Insert(true);
    end;
}
