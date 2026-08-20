export function formatAge(dateOfBirth: number, now: number): string {
  const days = Math.max(0, Math.floor((now - dateOfBirth) / 86_400_000));
  if (days < 14) return `${days} day${days === 1 ? "" : "s"}`;
  const weeks = Math.floor(days / 7);
  if (weeks < 13) return `${weeks} week${weeks === 1 ? "" : "s"}`;
  const months = Math.floor(days / 30.437);
  if (months < 24) return `${months} month${months === 1 ? "" : "s"}`;
  const years = Math.floor(months / 12);
  const rem = months % 12;
  if (rem === 0) return `${years} year${years === 1 ? "" : "s"}`;
  return `${years}y ${rem}mo`;
}

export function formatKg(grams: number): string {
  return `${(grams / 1000).toFixed(grams % 1000 === 0 ? 0 : 2)} kg`;
}

const MONTHS_SHORT = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
] as const;

export function formatDob(ms: number): string {
  const date = new Date(ms);
  return `${date.getUTCDate()} ${MONTHS_SHORT[date.getUTCMonth()]} ${date.getUTCFullYear()}`;
}

export type WeightUnit = "kg" | "lb";

const GRAMS_PER_LB = 453.59237;
const GRAMS_PER_OZ = 28.349523125;

export function gramsToKgParts(grams: number): { kg: number; tenths: number } {
  const totalTenths = Math.round(grams / 100);
  return {
    kg: Math.floor(totalTenths / 10),
    tenths: totalTenths % 10,
  };
}

export function kgPartsToGrams(kg: number, tenths: number): number {
  return Math.round((kg + tenths / 10) * 1000);
}

export function gramsToLbOz(grams: number): { lb: number; oz: number } {
  const totalOz = Math.round(grams / GRAMS_PER_OZ);
  return {
    lb: Math.floor(totalOz / 16),
    oz: totalOz % 16,
  };
}

export function lbOzToGrams(lb: number, oz: number): number {
  return Math.round(lb * GRAMS_PER_LB + oz * GRAMS_PER_OZ);
}

export function formatWeight(grams: number, unit: WeightUnit = "kg"): string {
  if (unit === "lb") {
    const { lb, oz } = gramsToLbOz(grams);
    return `${lb} lb ${oz} oz`;
  }
  const { kg, tenths } = gramsToKgParts(grams);
  return tenths === 0 ? `${kg} kg` : `${kg}.${tenths} kg`;
}

export type HeightUnit = "cm" | "in";

const CM_PER_INCH = 2.54;

export function cmToParts(cm: number): { whole: number; tenths: number } {
  const totalTenths = Math.round(cm * 10);
  return {
    whole: Math.floor(totalTenths / 10),
    tenths: totalTenths % 10,
  };
}

export function cmPartsToCm(whole: number, tenths: number): number {
  return Math.round((whole + tenths / 10) * 10) / 10;
}

export function cmToFtIn(cm: number): { ft: number; inch: number } {
  const totalInches = Math.round(cm / CM_PER_INCH);
  return {
    ft: Math.floor(totalInches / 12),
    inch: totalInches % 12,
  };
}

export function ftInToCm(ft: number, inch: number): number {
  return Math.round((ft * 12 + inch) * CM_PER_INCH * 10) / 10;
}

export function formatHeight(cm: number, unit: HeightUnit = "cm"): string {
  if (unit === "in") {
    const { ft, inch } = cmToFtIn(cm);
    return `${ft}′ ${inch}″`;
  }
  const { whole, tenths } = cmToParts(cm);
  return tenths === 0 ? `${whole} cm` : `${whole}.${tenths} cm`;
}

export function formatRelative(loggedAt: number, now: number): string {
  const delta = Math.max(0, now - loggedAt);
  const minutes = Math.floor(delta / 60_000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ${minutes % 60}m ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export function parseDob(input: string): number | null {
  const trimmed = input.trim();
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(trimmed);
  const uk = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(trimmed);
  let year: number;
  let month: number;
  let day: number;
  if (iso) {
    year = Number(iso[1]);
    month = Number(iso[2]);
    day = Number(iso[3]);
  } else if (uk) {
    day = Number(uk[1]);
    month = Number(uk[2]);
    year = Number(uk[3]);
  } else {
    return null;
  }
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null;
  }
  return date.getTime();
}

export function dobToInput(ms: number): string {
  const date = new Date(ms);
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function parseKg(input: string): number | null {
  const n = Number(input.trim().replace(",", "."));
  if (!Number.isFinite(n) || n <= 0 || n > 30) return null;
  return Math.round(n * 1000);
}
