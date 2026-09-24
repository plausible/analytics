type PlausibleTracker = (
  event: string,
  options?: { props?: Record<string, string> }
) => void

export function trackEvent(
  event: string,
  props?: Record<string, string>
): void {
  const plausible = (window as unknown as { plausible?: PlausibleTracker })
    .plausible
  if (typeof plausible === 'function') {
    plausible(event, props ? { props } : undefined)
  }
}
