import { runThrottledCheck } from "./run-check"

export async function snippetCheckV1(expectedDataDomain, log) {
  log('Starting snippet detection...')

  let snippetCounts = await waitForFirstSnippet(log)

  if (snippetCounts.all > 0) {
    log('Waiting for additional snippets to appear...')
    snippetCounts = await waitForAdditionalSnippets(log)
  }

  log(`Final snippet count: head=${snippetCounts.head}, body=${snippetCounts.body}`)
    
  return {
    snippetCounts: snippetCounts,
    dataDomainMismatch: checkDataDomainMismatch(expectedDataDomain, log)
  }
}

function checkDataDomainMismatch(expectedDataDomain, log) {
  const snippets = [...getHeadSnippets(), ...getBodySnippets()]

  if (snippets.length === 0) return false

  return snippets.some(snippet => {
    const scriptDataDomain = snippet.getAttribute('data-domain')
    if (!scriptDataDomain) return false

    const multiple = scriptDataDomain.split(',').map(d => d.trim())
    const dataDomainMismatch = !multiple.some((domain) => domain.replace(/^www\./, '') === expectedDataDomain)
    log(`Data domain mismatch: ${dataDomainMismatch}`)
    return dataDomainMismatch
  })
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

async function waitForFirstSnippet(log) {
  const checkFn = (opts) => {
    const snippetsFound = countSnippets()
    
    if (snippetsFound.all > 0) {
      log(`Found snippets: head=${snippetsFound.head}; body=${snippetsFound.body}`)
      return snippetsFound
    }

    if (opts.timeout) {
      log('No snippets found after 5 seconds') 
      return snippetsFound
    }

    return 'continue'
  }

  return await runThrottledCheck(checkFn, {timeout: 5000, interval: 100})
}

async function waitForAdditionalSnippets(log) {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve(countSnippets())
    }, 1000)
  })
}