export type Screen =
  | "login"
  | "home"
  | "lp"
  | "receiving"
  | "picking"
  | "adhoc"
  | "directed"
  | "count"
  | "putaway"
  | "shipping"
  | "production"
  | "assembly"
  | "quality"
  | "inquiry"
  | "binInquiry"
  | "posting"
  | "qms"
  | "printers"
  | "selfTest";

export const SCREEN_TITLES: Record<Screen, string> = {
  login: "Giriş",
  home: "Ana Menü",
  lp: "License Plate",
  receiving: "Mal Kabul",
  picking: "Toplama",
  adhoc: "Ad-Hoc Hareket",
  directed: "Yönlendirilmiş",
  count: "Sayım",
  putaway: "Put-Away",
  shipping: "Sevkiyat",
  production: "Üretim",
  assembly: "Montaj",
  quality: "Kalite",
  inquiry: "Item Inquiry",
  binInquiry: "Bin Inquiry",
  posting: "Posting Test",
  qms: "Quality Management (MS)",
  printers: "Yazıcılar",
  selfTest: "Sistem Sağlığı",
};
