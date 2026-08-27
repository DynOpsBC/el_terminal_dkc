codeunit 72035 "DOPSWHS Permission Helper"
{
    Access = Internal;

    procedure EnsureCanModifySetup()
    begin
        if not CanModifySetup() then
            Error('You do not have permission to modify Advanced WMS setup.');
    end;

    procedure CanModifySetup(): Boolean
    var
        Setup: Record "DOPSWHS Setup";
    begin
        exit(Setup.WritePermission());
    end;
}

