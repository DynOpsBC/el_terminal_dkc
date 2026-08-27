interface "DOPSWHS PutAway Strategy"
{
    procedure SuggestBin(Item: Record Item; Qty: Decimal; LocationCode: Code[10]; var BinCode: Code[20]; var Reason: Text): Boolean;
}
