window.verifyPlausibleInstallation = async function(expectedDataDomain, debug) {
  function log(message) {
    if (debug) console.log('[Plausible Verification]', message)
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

  async function snippetCheck() {
    log('Starting snippet detection...')

    let snippetData = await waitForSnippets()

    if (snippetData.all > 0) {
      log('Waiting for additional snippets to appear...')
      snippetData = await waitForSnippets(snippetData.all)
    }

    log(`Final snippet count: head=${snippetData.head}, body=${snippetData.body}`)
    
    return snippetData
  }

  function waitForSnippets(alreadyFound = 0) {
    return new Promise((resolve) => {
      let snippetsFound = countSnippets()

      const totalChecks = alreadyFound > 0 ? 10 : 50
      let checkCount = 0

      const snippetInterval = setInterval(() => {
        if (checkCount === totalChecks) {
          clearInterval(snippetInterval)
          resolve(snippetsFound)
        }

        snippetsFound = countSnippets()
        checkCount++
        
        if (snippetsFound.all > alreadyFound) {
          clearInterval(snippetInterval)
          log(`Found snippets: head=${snippetsFound.head}; body=${snippetsFound.body}`)
          resolve(snippetsFound)
        } else if (checkCount >= totalChecks) {
          clearInterval(snippetInterval)
          log('No snippets found after 5 seconds')
          resolve(snippetsFound)
        }
      }, 100)
    })
  }

  function checkDataDomainMismatch() {
    const snippets = [...getHeadSnippets(), ...getBodySnippets()]

    if (snippets.length === 0) return false

    return snippets.some(snippet => {
      const scriptDataDomain = snippet.getAttribute('data-domain')
      if (!scriptDataDomain) return false

      const multiple = scriptDataDomain.split(',').map(d => d.trim())
      const dataDomainMismatch = !multiple.includes(expectedDataDomain)
      log(`Data domain mismatch: ${dataDomainMismatch}`)
      return dataDomainMismatch
    })
  }

  async function plausibleFunctionCheck() {
    log('Checking for Plausible function...')
    const plausibleFound = await waitForPlausibleFunction()
      
    if (plausibleFound) {
      log('Plausible function found. Executing test event...')
      const callbackResult = await testPlausibleCallback()
      log(`Test event callback response: ${callbackResult.status}`)
      return { plausibleInstalled: true, callbackStatus: callbackResult.status }
    } else {
      log('Plausible function not found')
      return { plausibleInstalled: false}
    }
  }

  function waitForPlausibleFunction() {
    return new Promise((resolve) => {
      const totalChecks = 50
      let checkCount = 0

      const i = setInterval(() => {
        if (window.plausible) {
          clearInterval(i)
          resolve(true)
        } else if (checkCount >= totalChecks) {
          clearInterval(i)
          resolve(false)
        }
        checkCount++
      }, 100)
    })
  }

  function testPlausibleCallback() {
    return new Promise((resolve) => {
      let callbackResolved = false

      const callbackTimeout = setTimeout(() => {
        if (!callbackResolved) {
          callbackResolved = true
          log('Timeout waiting for Plausible function callback')
          resolve({ status: undefined })
        }
      }, 5000)

      try {
        window.plausible('verification-agent-test', {
          callback: function(options) {
            if (!callbackResolved) {
              callbackResolved = true
              clearTimeout(callbackTimeout)
              resolve({status: options && options.status})
            }
          }
        })
      } catch (error) {
        if (!callbackResolved) {
          callbackResolved = true
          clearTimeout(callbackTimeout)
          log('Error calling plausible function:', error)
          resolve({ status: -1 })
        }
      }
    })
  }

  const [snippetData, plausibleFunctionData] = await Promise.all([
    snippetCheck(),
    plausibleFunctionCheck()
  ])

  return {
    data: {
      completed: true,
      plausibleInstalled: plausibleFunctionData.plausibleInstalled,
      callbackStatus: plausibleFunctionData.callbackStatus || 0,
      snippetsFoundInHead: snippetData.head,
      snippetsFoundInBody: snippetData.body,
      dataDomainMismatch: checkDataDomainMismatch(snippetData)
    }
  }
}