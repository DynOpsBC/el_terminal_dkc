import admin from "firebase-admin";

export type FcmPayload = {
  token: string;
  data: Record<string, string>;
  title: string;
  body: string;
};

export class FcmClient {
  constructor() {
    if (admin.apps.length === 0) {
      admin.initializeApp();
    }
  }

  async send(payload: FcmPayload) {
    return admin.messaging().send({
      token: payload.token,
      notification: { title: payload.title, body: payload.body },
      data: payload.data,
    });
  }
}
