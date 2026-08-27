codeunit 72218 "DOPSWHS Lot Serial Generator"
{
    // Otomatik Lot/Seri numarası üretimi — müşteri isteği (WI "auto lot/serial").
    // Setup'ta ilgili No. Series tanımlıysa numara üretir; tanımlı değilse boş
    // döner (elle giriş). SSCCGenerator ile aynı No. Series desenini kullanır.
    Access = Public;

    procedure GenerateLotNo(): Code[50]
    var
        Setup: Record "DOPSWHS Setup";
        NoSeries: Codeunit "No. Series";
    begin
        Setup.Get('');
        if Setup."Lot No. Series" = '' then
            exit('');
        exit(CopyStr(NoSeries.GetNextNo(Setup."Lot No. Series"), 1, 50));
    end;

    /// <summary>
    /// Generates the internal lot number from the standard Lot Nos. series on
    /// the item card. The WMS-wide setup series is retained only as a fallback
    /// for existing tenants that have not populated Item."Lot Nos." yet.
    /// </summary>
    procedure GenerateLotNoForItem(ItemNo: Code[20]): Code[50]
    var
        Item: Record Item;
        NoSeries: Codeunit "No. Series";
    begin
        if Item.Get(ItemNo) then
            if Item."Lot Nos." <> '' then
                exit(CopyStr(NoSeries.GetNextNo(Item."Lot Nos."), 1, 50));

        exit(GenerateLotNo());
    end;

    procedure GenerateSerialNo(): Code[50]
    var
        Setup: Record "DOPSWHS Setup";
        NoSeries: Codeunit "No. Series";
    begin
        Setup.Get('');
        if Setup."Serial No. Series" = '' then
            exit('');
        exit(CopyStr(NoSeries.GetNextNo(Setup."Serial No. Series"), 1, 50));
    end;
}
