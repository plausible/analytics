export function roundedPercentage(value, total) {
  const percentage = (value / total) * 100
  // Rounding to 2 decimal places using Math.round()
  // (https://stackoverflow.com/a/11832950)
  return Math.round((percentage + Number.EPSILON) * 100) / 100
}

