export const REALTIME_UPDATE_TIME_MS = 30_000
const tickEvent = new Event('tick')

export function start() {
  setInterval(() => {
    document.dispatchEvent(tickEvent)
  }, REALTIME_UPDATE_TIME_MS)
}
