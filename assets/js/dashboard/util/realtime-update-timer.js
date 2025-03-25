const THIRTY_SECONDS = 30000
const tickEvent = new Event('tick')

export function start() {
  setInterval(() => {
    document.dispatchEvent(tickEvent)
  }, THIRTY_SECONDS)
}
