import { PublicClientApplication, type Configuration } from "@azure/msal-browser";

// Multi-tenant by default. Each customer admin signs in with their own AAD
// account; we read `tid` from the issued ID token claims to drive everything.
const clientId = (import.meta.env.VITE_PORTAL_CLIENT_ID as string | undefined) ?? "";
const authority = (import.meta.env.VITE_PORTAL_AUTHORITY as string | undefined) ?? "https://login.microsoftonline.com/common";

export const msalConfig: Configuration = {
  auth: {
    clientId,
    authority,
    redirectUri: window.location.origin,
    postLogoutRedirectUri: window.location.origin,
  },
  cache: {
    cacheLocation: "localStorage",
    storeAuthStateInCookie: false,
  },
};

export const loginRequest = {
  scopes: ["openid", "profile", "email"],
};

export const msalInstance = new PublicClientApplication(msalConfig);
