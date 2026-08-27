import { reassign } from "../../al-bridge/ControlAddInBridge";

export function reassignPick(pickNo: string, userId: string) {
  reassign(pickNo, userId);
}
