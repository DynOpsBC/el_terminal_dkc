// Microsoft Quality Management API client (api/microsoft/qualityManagement/v1.0).
//
// MS QM ships its own first-party REST API on BC v28+. We reuse the AAD token
// stored by bcApi.ts (login persistence is shared) and just override the base
// URL. The key field is SystemId (GUID), used by all bound actions:
//
//   POST qualityInspections(<SystemId>)/Microsoft.NAV.FinishInspection
//   POST qualityInspections(<SystemId>)/Microsoft.NAV.SetTestValue
//   POST qualityInspections(<SystemId>)/Microsoft.NAV.BlockLot
//   ... etc.

import * as BcApi from "./bcApi";

const QM_GROUP = "qualityManagement";
const QM_PUBLISHER = "microsoft";
const QM_VERSION = "v1.0";

function qmBase(): string {
  return `${BcApi.BC_RESOURCE}/v2.0/${BcApi.TENANT}/${BcApi.getEnvironment()}/api/${QM_PUBLISHER}/${QM_GROUP}/${QM_VERSION}/companies(${BcApi.getCompanyId()})`;
}

/** GET `<qm-base>/<path>` */
export function get(path: string): Promise<BcApi.ApiResult> {
  return BcApi.get(`${qmBase()}/${path}`);
}

/** POST `<qm-base>/<path>` with JSON body */
export function post(path: string, body: string): Promise<BcApi.ApiResult> {
  return BcApi.post(`${qmBase()}/${path}`, body);
}

/** PATCH `<qm-base>/<path>` */
export function patch(path: string, body: string): Promise<BcApi.ApiResult> {
  return BcApi.patch(`${qmBase()}/${path}`, body);
}

export function inspectionKey(systemId: string): string {
  return `'${systemId.replace(/'/g, "''")}'`;
}

/** Bound action — `qualityInspections(<systemId>)/Microsoft.NAV.<action>` */
export function boundAction(systemId: string, action: string, body: string): Promise<BcApi.ApiResult> {
  return post(`qualityInspections(${inspectionKey(systemId)})/Microsoft.NAV.${action}`, body);
}

/**
 * createQualityInspections is on a temporary Name/Value buffer; the system ID
 * is the *source record's* SystemId (e.g. a Posted Purchase Receipt Line).
 */
export function createInspectionFromRecord(
  sourceSystemId: string,
  tableName: string,
): Promise<BcApi.ApiResult> {
  return post(
    `createQualityInspections(${inspectionKey(sourceSystemId)})/Microsoft.NAV.CreateInspectionFromRecordID`,
    JSON.stringify({ tableName }),
  );
}

// Re-export parsers for symmetry with bcApi
export const { parseValueArray, firstValue, scalarValue, errorMessage } = BcApi;
