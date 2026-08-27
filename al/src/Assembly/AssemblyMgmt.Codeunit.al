codeunit 72049 "DOPSWHS Assembly Mgmt"
{
    Access = Public;

    procedure PostAssembly(var AssemblyHeader: Record "Assembly Header")
    var
        LockedAssemblyHeader: Record "Assembly Header";
        AssemblyPost: Codeunit "Assembly-Post";
        DocumentNo: Code[20];
    begin
        // API tekrarları ve iki terminalin aynı montajı eşzamanlı post etmesi
        // aynı miktarın iki kez işlenmesine dönüşmemelidir. Kaydı kilit altında
        // yeniden okuyup yalnız güncel Released belgeyi standart post codeunit'ine
        // veririz; ikinci istek ilk transaction bittikten sonra güncel durumu görür.
        LockedAssemblyHeader.LockTable();
        if not LockedAssemblyHeader.Get(AssemblyHeader."Document Type", AssemblyHeader."No.") then
            Error('Assembly order %1 no longer exists or has already been posted.', AssemblyHeader."No.");
        LockedAssemblyHeader.TestField(Status, LockedAssemblyHeader.Status::Released);
        AssemblyHeader := LockedAssemblyHeader;
        DocumentNo := LockedAssemblyHeader."No.";

        if LockedAssemblyHeader."Assemble to Order" then
            LogTelemetry('AdvWMS.Assembly.AssembleToOrderTracked', DocumentNo);

        AssemblyPost.Run(LockedAssemblyHeader);
        AssemblyHeader := LockedAssemblyHeader;
        LogTelemetry('AdvWMS.Assembly.Posted', DocumentNo);
    end;

    local procedure LogTelemetry(EventName: Text; DocumentNo: Code[20])
    var
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        Telemetry.LogInfo(EventName, DocumentNo);
    end;
}
