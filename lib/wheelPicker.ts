/** iOS reports leftover velocity when a flick will keep decelerating. */
export function shouldCommitOnEndDrag(velocityY: number | undefined): boolean {
  return Math.abs(velocityY ?? 0) < 0.01;
}

export function wheelIndexFromOffset(
  offsetY: number,
  itemCount: number,
  itemHeight: number,
): number {
  if (itemCount <= 0) return 0;
  return Math.max(
    0,
    Math.min(itemCount - 1, Math.round(offsetY / itemHeight)),
  );
}
