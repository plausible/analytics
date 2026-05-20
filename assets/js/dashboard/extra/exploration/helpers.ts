export function roundedPercentage(value: number, total: number): number {
  const percentage: number = (value / total) * 100
  // Rounding to 2 decimal places using Math.round()
  // (https://stackoverflow.com/a/11832950)
  return Math.round((percentage + Number.EPSILON) * 100) / 100
}
