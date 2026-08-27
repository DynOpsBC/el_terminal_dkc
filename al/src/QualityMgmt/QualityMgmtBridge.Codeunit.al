// ============================================================================
// GEÇİCİ OLARAK DEVRE DIŞI — BC 28'e geçince geri açın.
//
// Bu codeunit, Microsoft Quality Management (BC v28 first-party) eklentisine
// bağımlıdır: "Qlty. Inspection Header" tablosu ve
// Microsoft.QualityManagement.Document namespace'i yalnızca BC 28'de vardır.
// Mevcut hedef BC 24.0 olduğu için bu semboller çözülemiyor ve yayınlama
// başarısız oluyordu (AL0791 / AL0185).
//
// Silinmedi — BC 28'e yükseltince aşağıdaki bloğun yorumunu kaldırın,
// app.json'a "Quality Management" bağımlılığını geri ekleyin ve izin
// setlerindeki ilgili satırların yorumunu kaldırın.
// ============================================================================
/*
namespace DynOps.Warehouse.QualityMgmt;

using Microsoft.QualityManagement.Document;

/// <summary>
/// Bridges Microsoft Quality Management (BC v28 first-party extension) into the
/// DOPSWHS warehouse flow.
///
/// MS QM exposes its own REST API (api/microsoft/qualityManagement/v1.0) which
/// mobile + web consume directly. This codeunit covers the AL side: public
/// procedures to query whether a Lot/Serial/Package has an open Quality
/// Inspection. DOPSWHS Pick / Put-Away / Movement codeunits call
/// VerifyNotBlocked() before register; if blocked, the raised Error uses a
/// format that BCWMSApp's mobile/web QcErrorParser picks up to render the
// / friendly " QC BLOCK" banner.
///
/// A direct event subscriber on Whse.-Activity-Register is intentionally
/// omitted in this commit — the exact event signature differs per BC build,
/// and the standalone procedures already cover the runtime path.
/// </summary>
codeunit 72079 "DOPSWHS Quality Mgmt Bridge"
{
    Access = Public;

    Permissions = tabledata "Qlty. Inspection Header" = r;

    /// <summary>
    /// Returns the No. of the open Quality Inspection blocking the given
    /// tracking values, or an empty code if nothing is blocked. Caller-friendly
    /// guard: empty filter values are ignored.
    /// </summary>
    procedure FindBlockingInspection(LotNo: Code[50]; SerialNo: Code[50]; PackageNo: Code[50]): Code[20]
    var
        QltyInspectionHeader: Record "Qlty. Inspection Header";
    begin
        // QC hold is a SAFETY gate, not a feature gate — we always look up
        // blocking inspections, even when the license is inactive or below
        // the Advanced tier. License-tier guard is enforced on the QM UI/API
        // affordances (Setup card actions, write paths), NOT on the read of
        // "is this lot blocked?". Skipping this would let unlicensed tenants
        // ship/move stock that quality has already held.
        if (LotNo = '') and (SerialNo = '') and (PackageNo = '') then
            exit('');

        QltyInspectionHeader.SetRange(Status, QltyInspectionHeader.Status::Open);

        if LotNo <> '' then begin
            QltyInspectionHeader.SetRange("Source Lot No.", LotNo);
            if QltyInspectionHeader.FindFirst() then
                exit(QltyInspectionHeader."No.");
            QltyInspectionHeader.SetRange("Source Lot No.");
        end;

        if SerialNo <> '' then begin
            QltyInspectionHeader.SetRange("Source Serial No.", SerialNo);
            if QltyInspectionHeader.FindFirst() then
                exit(QltyInspectionHeader."No.");
            QltyInspectionHeader.SetRange("Source Serial No.");
        end;

        if PackageNo <> '' then begin
            QltyInspectionHeader.SetRange("Source Package No.", PackageNo);
            if QltyInspectionHeader.FindFirst() then
                exit(QltyInspectionHeader."No.");
        end;

        exit('');
    end;

    /// <summary>
    /// Hard guard — throws an Error if any tracking value is blocked. Error
    /// text is formatted for QcErrorParser ("blocked by quality inspection
    /// INS-NNNN").
    /// </summary>
    procedure VerifyNotBlocked(LotNo: Code[50]; SerialNo: Code[50]; PackageNo: Code[50])
    var
        BlockingInspNo: Code[20];
    begin
        BlockingInspNo := FindBlockingInspection(LotNo, SerialNo, PackageNo);
        if BlockingInspNo = '' then
            exit;
        Error(QcBlockedErr, BlockingInspNo);
    end;

    var
        QcBlockedErr: Label 'Bu kayıtta lot/serial/package %1 numaralı Quality Inspection ile blokda. blocked by quality inspection %1', Comment = '%1 = inspection no';
}
*/
