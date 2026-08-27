import React from "react";
import type { Screen } from "../routes";

interface HomeProps {
  navigate: (s: Screen) => void;
}

interface Tile {
  key: Screen;
  icon: string;
  label: string;
  enabled: boolean;
}

const TILES: Tile[] = [
  { key: "lp", icon: "📦", label: "License Plate", enabled: true },
  { key: "receiving", icon: "📥", label: "Mal Kabul", enabled: true },
  { key: "picking", icon: "🚚", label: "Toplama", enabled: true },
  { key: "adhoc", icon: "↔️", label: "Ad-Hoc Hareket", enabled: true },
  { key: "directed", icon: "🎯", label: "Yönlendirilmiş", enabled: true },
  { key: "count", icon: "🔢", label: "Sayım", enabled: true },
  { key: "putaway", icon: "📮", label: "Put-Away", enabled: true },
  { key: "shipping", icon: "🚢", label: "Sevkiyat", enabled: true },
  { key: "production", icon: "🏭", label: "Üretim", enabled: true },
  { key: "assembly", icon: "🔧", label: "Montaj", enabled: true },
  { key: "quality", icon: "🔬", label: "Kalite Denetimi", enabled: true },
  { key: "inquiry", icon: "🔍", label: "Item Inquiry", enabled: true },
  { key: "binInquiry", icon: "🪣", label: "Bin Inquiry", enabled: true },
  { key: "posting", icon: "🧪", label: "Posting Test", enabled: true },
  { key: "qms", icon: "🔬", label: "MS Quality Mgmt", enabled: true },
  { key: "printers", icon: "🖨", label: "Yazıcılar", enabled: true },
  { key: "selfTest", icon: "🩺", label: "Sistem Sağlığı", enabled: true },
];

export function Home({ navigate }: HomeProps) {
  return (
    <div>
      <h2 style={{ margin: "0 0 4px 0" }}>DynOps Warehouse Management</h2>
      <div style={{ color: "var(--text-muted)", fontSize: 13, marginBottom: 18 }}>
        BC paritesi web istasyonu — mobil app ile aynı operasyon kapsamı.
      </div>

      <div className="tiles">
        {TILES.map((t) => (
          <div
            key={t.key}
            className={`tile ${t.enabled ? "" : "disabled"}`}
            onClick={() => t.enabled && navigate(t.key)}
            title={t.enabled ? "" : "Bu modül web app'te henüz aktif değil — mobil app'te mevcut."}
          >
            <div className="icon">{t.icon}</div>
            <div className="label">{t.label}</div>
            {!t.enabled && <div style={{ fontSize: 11, color: "var(--text-muted)" }}>Yakında</div>}
          </div>
        ))}
      </div>
    </div>
  );
}
