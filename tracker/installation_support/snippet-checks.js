import { runThrottledCheck } from "./run-check"

export async function waitForBootstrappers(log) {
  log('Starting bootstrapper detection...')

  const initScripts = await getPlausibleInitScripts()
  log(`Final bootstrapper count: ${initScripts.length}`)
  return initScripts
}

export async function waitForSnippetsV1(log) {
  log('Starting snippet detection...')

  let snippetCounts = await waitForFirstSnippet()

  if (snippetCounts.all > 0) {
    log(`Found snippets: head=${snippetCounts.head}; body=${snippetCounts.body}`)
    log('Waiting for additional snippets to appear...')

    snippetCounts = await waitForAdditionalSnippets()

    log(`Final snippet count: head=${snippetCounts.head}; body=${snippetCounts.body}`)
  } else {
    log('No snippets found after 5 seconds') 
  }

  return {
    nodes: [...getHeadSnippets(), ...getBodySnippets()],
    counts: snippetCounts,
  }
}

function getHeadSnippets() {
  return document.querySelectorAll('head script[data-domain][src]')
}

function getBodySnippets() {
  return document.querySelectorAll('body script[data-domain][src]')
}

function countSnippets() {
  const headSnippets = getHeadSnippets()
  const bodySnippets = getBodySnippets()
  
  return {
    head: headSnippets.length,
    body: bodySnippets.length,
    all: headSnippets.length + bodySnippets.length
  }
}

async function getPlausibleInitScripts() {
  return await runThrottledCheck((opts) => {
    const bootstrappers = Array.from(document.querySelectorAll('script')).filter(script => script.textContent?.includes('plausible.init('))

    if (bootstrappers.length > 0 || opts.timeout) {
      return bootstrappers
    }

    return 'continue'
  }, {timeout: 5000, interval: 100})
}

// from script calling 'plausible.init(', extract all injected script node src attribute values
// handles double quoted src attributes only
export function getPlausibleInitScriptSrcs(script) {
  return Array.from(script.textContent.matchAll(/\.src=\s*"([^"]+)"/g, (m) => m[0]))
}

// from script calling 'plausible.init(', extract all domain values
// handles double quoted domain values only
export function getPlausibleInitScriptDomains(script) {
  return Array.from(script.textContent.matchAll(/\domain:\s*"([^"]+)"/g, (m) => m[0]))
}


async function waitForFirstSnippet() {
  const checkFn = (opts) => {
    const snippetsFound = countSnippets()
    
    if (snippetsFound.all > 0 || opts.timeout) {
      return snippetsFound
    }

    return 'continue'
  }

  return await runThrottledCheck(checkFn, {timeout: 5000, interval: 100})
}

async function waitForAdditionalSnippets() {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve(countSnippets())
    }, 1000)
  })
}