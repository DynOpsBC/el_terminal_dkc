report 72093 "DOPSWHS Count Variance"
{
    Caption = 'Count Variance';
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    DefaultLayout = RDLC;

    dataset
    {
        dataitem(CountSheetHeader; "DOPSWHS Count Sheet Header")
        {
            RequestFilterFields = "No.", "Location Code";
            column(No_; "No.") { }
            column(Location_Code; "Location Code") { }
            dataitem(CountSheetLine; "DOPSWHS Count Sheet Line")
            {
                DataItemLink = "Sheet No." = field("No.");
                column(Item_No_; "Item No.") { }
                column(Bin_Code; "Bin Code") { }
                column(LP_No_; "LP No.") { }
                column(Lot_No_; "Lot No.") { }
                column(Serial_No_; "Serial No.") { }
                column(System_Qty; "System Qty") { }
                column(Counted_Qty_1; "Counted Qty 1") { }
                column(Counted_Qty_2; "Counted Qty 2") { }
                column(Counted_Qty_3; "Counted Qty 3") { }
                column(Variance; Variance) { }
            }
        }
    }
}
