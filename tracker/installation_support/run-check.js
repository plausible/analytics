export async function runThrottledCheck(checkFn, { timeout, interval }) {
  return runCheckRecursive(checkFn, timeout, interval, 1)
}

async function runCheckRecursive(checkFn, timeout, interval, iteration) {
  return new Promise((resolve) => {
    if (iteration * interval >= timeout) {
      resolve(checkFn({ timeout: true }))
    } else if (checkFn({ timeout: false }) !== 'continue') {
      resolve(checkFn({ timeout: false }))
    } else {
      setTimeout(() => {
        resolve(runCheckRecursive(checkFn, timeout, interval, iteration + 1))
      }, interval)
    }
  })
}
