/**
 * Quality-related API error parser (web counterpart of QcErrorParser.kt).
 *
 * MS Quality Management + DOPSWHS workflow events block Picks / Put-Aways
 * when a referenced lot/serial/package has an open Quality Inspection that
 * has not yet finished with a passing result. BC surfaces these blocks as
 * error responses on the bound action call.
 *
 * The web UI uses this helper to detect QC-block errors and render a
 * friendly banner with a deep-link to the Quality module instead of a raw
 * HTTP error string.
 */

const INSPECTION_NO_REGEX = /\b(?:INS|QI|Q|QM)[-_]?\d{1,8}\b/;
const QC_KEYWORDS = ["quality", "inspection", "qc", "blocked", "blok"];

export function isQcBlocked(errMsg: string | null | undefined): boolean {
  if (!errMsg) return false;
  const lower = errMsg.toLowerCase();
  const hits = QC_KEYWORDS.filter((k) => lower.includes(k)).length;
  return hits >= 2 || INSPECTION_NO_REGEX.test(errMsg);
}

export function extractInspectionNo(errMsg: string | null | undefined): string | null {
  if (!errMsg) return null;
  const m = errMsg.match(INSPECTION_NO_REGEX);
  return m ? m[0] : null;
}

export function friendlyQcStatus(errMsg: string | null | undefined, httpCode = 0): string {
  const raw = errMsg ?? "Bilinmeyen hata";
  if (!isQcBlocked(raw)) return `HATA: ${raw} (HTTP ${httpCode})`;
  const ins = extractInspectionNo(raw);
  const tail = ins
    ? `Quality Inspection ${ins} tamamlanmalı.`
    : "Açık bir Quality Inspection bekliyor.";
  return `🔬 QC BLOCK: Lot/Serial bloklu — ${tail} (HTTP ${httpCode})`;
}
