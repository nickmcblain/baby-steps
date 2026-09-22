/** Published 24h sleep ranges. Not a target. Not medical advice. */
export function sleepDurationRange(
  dateOfBirth: number,
  now: number,
): { lowHours: number; highHours: number } {
  const days = Math.max(0, (now - dateOfBirth) / 86_400_000);
  // NSF Hirshkowitz et al. 2015 — newborns 14–17h. NHS notes wider variation.
  if (days < 90) return { lowHours: 14, highHours: 17 };
  // AASM Paruthi et al. 2016 — 4–12 months 12–16h. Switch at 90 days.
  if (days < 365) return { lowHours: 12, highHours: 16 };
  // NSF / AASM toddler 1–2 years.
  return { lowHours: 11, highHours: 14 };
}

export function typicalFeedCount(dateOfBirth: number, now: number): number {
  const days = Math.max(0, (now - dateOfBirth) / 86_400_000);
  if (days < 56) return 8;
  if (days < 180) return 6;
  return 5;
}

export function typicalNappyCount(dateOfBirth: number, now: number): number {
  const days = Math.max(0, (now - dateOfBirth) / 86_400_000);
  if (days < 56) return 8;
  return 6;
}
