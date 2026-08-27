import React from "react";
import { createRoot } from "react-dom/client";
import { LpBrowserApp } from "./LpBrowserApp";
import "./styles.css";

const root = document.getElementById("lp-browser-root");
if (root) {
  createRoot(root).render(
    <React.StrictMode>
      <LpBrowserApp />
    </React.StrictMode>,
  );
}
