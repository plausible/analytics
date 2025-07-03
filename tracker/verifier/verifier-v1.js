import { snippetCheckV1 } from "./snippet-checks"
import { plausibleFunctionCheck } from "./plausible-function-check"

window.verifyPlausibleInstallation = async function(expectedDataDomain, debug) {
  function log(message) {
    if (debug) console.log('[Plausible Verification]', message)
  }

  const [snippetDiagnostics, plausibleFunctionDiagnostics] = await Promise.all([
    snippetCheckV1(expectedDataDomain, log),
    plausibleFunctionCheck(log)
  ])

  return {
    data: {
      completed: true,
      plausibleInstalled: plausibleFunctionDiagnostics.plausibleInstalled,
      callbackStatus: plausibleFunctionDiagnostics.callbackStatus || 0,
      snippetsFoundInHead: snippetDiagnostics.snippetCounts.head,
      snippetsFoundInBody: snippetDiagnostics.snippetCounts.body,
      dataDomainMismatch: snippetDiagnostics.dataDomainMismatch
    }
  }
}