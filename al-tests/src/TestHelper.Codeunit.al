codeunit 72140 "DOPSWHS Test Helper"
{
    Subtype = Test;

    procedure ResetSetup()
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if Setup.Get('') then
            Setup.Delete();
    end;

    procedure EnsureSetup(): Record "DOPSWHS Setup"
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup.Insert(true);
        end;

        exit(Setup);
    end;
}

