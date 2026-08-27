/** Typical 24h sleep hours by age. NHS-ish bands, not medical advice. */
export function typicalSleepHours(dateOfBirth: number, now: number): number {
  const days = Math.max(0, (now - dateOfBirth) / 86_400_000);
  if (days < 90) return 15.5;
  if (days < 180) return 14;
  if (days < 365) return 13;
  return 12;
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