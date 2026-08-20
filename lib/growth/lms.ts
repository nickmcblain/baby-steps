import {
  type Sex,
  type LmsTuple,
  WHO_LENGTH_LMS,
  WHO_WEIGHT_LMS,
} from "./whoLmsData";

export type { Sex };

/** UK Red Book / UK-WHO printed centile lines */
export const UK_CENTILES = [
  { label: "0.4th", z: -2.65207 },
  { label: "2nd", z: -2.05375 },
  { label: "9th", z: -1.34076 },
  { label: "25th", z: -0.67449 },
  { label: "50th", z: 0 },
  { label: "75th", z: 0.67449 },
  { label: "91st", z: 1.34076 },
  { label: "98th", z: 2.05375 },
  { label: "99.6th", z: 2.65207 },
] as const;

export type GrowthMetric = "weight" | "length";

const MS_PER_MONTH = 30.4375 * 86_400_000;

export function ageMonths(dateOfBirth: number, at: number): number {
  return Math.max(0, (at - dateOfBirth) / MS_PER_MONTH);
}

function tableFor(metric: GrowthMetric, sex: Sex): LmsTuple[] {
  return metric === "weight" ? WHO_WEIGHT_LMS[sex] : WHO_LENGTH_LMS[sex];
}

function interpolateLms(
  table: LmsTuple[],
  month: number,
): { L: number; M: number; S: number } | null {
  if (table.length === 0) return null;
  const clamped = Math.min(Math.max(month, table[0][0]), table[table.length - 1][0]);
  let i = 0;
  while (i < table.length - 1 && table[i + 1][0] < clamped) i += 1;
  const [m0, L0, M0, S0] = table[i];
  if (i === table.length - 1 || m0 === clamped) {
    return { L: L0, M: M0, S: S0 };
  }
  const [m1, L1, M1, S1] = table[i + 1];
  const t = (clamped - m0) / (m1 - m0);
  return {
    L: L0 + t * (L1 - L0),
    M: M0 + t * (M1 - M0),
    S: S0 + t * (S1 - S0),
  };
}

/** Measurement from z-score via LMS (Cole & Green). */
export function valueFromZ(
  metric: GrowthMetric,
  sex: Sex,
  month: number,
  z: number,
): number | null {
  const lms = interpolateLms(tableFor(metric, sex), month);
  if (!lms) return null;
  const { L, M, S } = lms;
  if (Math.abs(L) < 1e-8) {
    return M * Math.exp(S * z);
  }
  return M * Math.pow(1 + L * S * z, 1 / L);
}

/** SDS / z-score for a measurement (kg or cm). */
export function zScore(
  metric: GrowthMetric,
  sex: Sex,
  month: number,
  value: number,
): number | null {
  if (!(value > 0)) return null;
  const lms = interpolateLms(tableFor(metric, sex), month);
  if (!lms) return null;
  const { L, M, S } = lms;
  if (Math.abs(L) < 1e-8) {
    return Math.log(value / M) / S;
  }
  return (Math.pow(value / M, L) - 1) / (L * S);
}

/** Approximate centile 0–100 from z (normal CDF). */
export function centileFromZ(z: number): number {
  // Abramowitz & Stegun approximation
  const t = 1 / (1 + 0.2316419 * Math.abs(z));
  const d = 0.3989423 * Math.exp((-z * z) / 2);
  const p =
    d *
    t *
    (0.3193815 +
      t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
  const cdf = z > 0 ? 1 - p : p;
  return Math.min(99.9, Math.max(0.1, cdf * 100));
}

export function formatCentile(centile: number): string {
  if (centile < 1) return `${centile.toFixed(1)}th`;
  if (centile >= 99) return `${centile.toFixed(1)}th`;
  const rounded = Math.round(centile);
  const mod10 = rounded % 10;
  const mod100 = rounded % 100;
  const suffix =
    mod10 === 1 && mod100 !== 11
      ? "st"
      : mod10 === 2 && mod100 !== 12
        ? "nd"
        : mod10 === 3 && mod100 !== 13
          ? "rd"
          : "th";
  return `${rounded}${suffix}`;
}

export type Band =
  | "very_low"
  | "low"
  | "typical"
  | "high"
  | "very_high"
  | "unknown";

export function growthBand(z: number | null): Band {
  if (z == null || !Number.isFinite(z)) return "unknown";
  if (z < -2.05) return "very_low"; // below ~2nd
  if (z < -1.34) return "low"; // below ~9th
  if (z > 2.05) return "very_high"; // above ~98th
  if (z > 1.34) return "high"; // above ~91st
  return "typical";
}

export function bandLabel(band: Band): string {
  switch (band) {
    case "very_low":
      return "Below the 2nd centile";
    case "low":
      return "Between 2nd and 9th centile";
    case "typical":
      return "Within expected range";
    case "high":
      return "Between 91st and 98th centile";
    case "very_high":
      return "Above the 98th centile";
    case "unknown":
      return "Add sex to see UK chart";
  }
}

export function maxChartMonths(dateOfBirth: number, now = Date.now()): number {
  const age = ageMonths(dateOfBirth, now);
  return Math.min(24, Math.max(6, Math.ceil(age + 1)));
}
