import React from "react";
import { createRoot } from "react-dom/client";
import { PickBoardApp } from "./PickBoardApp";

const root = document.getElementById("root");

if (root) {
  createRoot(root).render(
    <React.StrictMode>
      <PickBoardApp />
    </React.StrictMode>,
  );
}
