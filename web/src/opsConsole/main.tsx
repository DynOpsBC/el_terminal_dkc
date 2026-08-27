import React from "react";
import { createRoot } from "react-dom/client";
import { OpsConsoleApp } from "./OpsConsoleApp";
import "./styles.css";

const root = document.getElementById("root");

if (root) {
  createRoot(root).render(
    <React.StrictMode>
      <OpsConsoleApp />
    </React.StrictMode>,
  );
}
