import React from "react";

export function StatusText({ status }: { status: string }) {
  if (!status) return null;
  let cls = "status";
  if (status.startsWith("PASS")) cls += " ok";
  else if (status.startsWith("HATA") || status.startsWith("ERR")) cls += " err";
  else if (status.startsWith("EMPTY")) cls += " empty";
  return <div className={cls}>{status}</div>;
}

export function EmptyState({ message }: { message: string }) {
  return <div className="empty">{message}</div>;
}

export function DocHeader({
  title,
  subtitle,
  percent,
}: {
  title: string;
  subtitle?: string;
  percent?: number;
}) {
  return (
    <div className="docheader">
      <h2>{title}</h2>
      {subtitle && <div className="meta">{subtitle}</div>}
      {typeof percent === "number" && (
        <div className="progress">
          <div style={{ width: `${Math.max(0, Math.min(100, percent))}%` }} />
        </div>
      )}
    </div>
  );
}

export function Pill({
  text,
  tone,
}: {
  text: string;
  tone?: "ok" | "warn" | "neutral";
}) {
  return <span className={`pill ${tone === "ok" ? "ok" : tone === "warn" ? "warn" : ""}`}>{text}</span>;
}

export function Tabs({
  tabs,
  active,
  onChange,
}: {
  tabs: { key: string; label: string }[];
  active: string;
  onChange: (k: string) => void;
}) {
  return (
    <div className="tabs">
      {tabs.map((t) => (
        <button
          key={t.key}
          className={`tab ${t.key === active ? "active" : ""}`}
          onClick={() => onChange(t.key)}
        >
          {t.label}
        </button>
      ))}
    </div>
  );
}

export function Modal({
  title,
  meta,
  onClose,
  children,
}: {
  title: string;
  meta?: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h3>{title}</h3>
        {meta && <div className="modal-meta">{meta}</div>}
        {children}
      </div>
    </div>
  );
}

export function Field({
  label,
  value,
  onChange,
  type = "text",
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: string;
  placeholder?: string;
}) {
  return (
    <div>
      <label className="field">{label}</label>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
      />
    </div>
  );
}

export function NumberField({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <div>
      <label className="field">{label}</label>
      <input
        type="number"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        step="any"
      />
    </div>
  );
}

export function Checkbox({
  label,
  value,
  onChange,
}: {
  label: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label style={{ display: "inline-flex", alignItems: "center", gap: 8, cursor: "pointer", fontSize: 13 }}>
      <input type="checkbox" checked={value} onChange={(e) => onChange(e.target.checked)} />
      {label}
    </label>
  );
}
