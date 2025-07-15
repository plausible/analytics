const SELECTORS = {
  // https://github.com/cavi-au/Consent-O-Matic/blob/master/rules/cookiebot.json
  // We check whether any of the selectors mentioner under
  // `cookiebot.detectors[0].showingMatcher[0].target.selector`
  // is visible on the page.
  cookiebot: [
    '#CybotCookiebotDialogBodyButtonAccept',
    '#CybotCookiebotDialogBody',
    '#CybotCookiebotDialogBodyLevelButtonPreferences',
    '#cb-cookieoverlay',
    '#CybotCookiebotDialog',
    '#cookiebanner',
  ]
}

function isVisible(element) {
  const style = window.getComputedStyle(element);

  return (
    style.display !== 'none' &&
    style.visibility !== 'hidden' &&
    element.offsetParent !== null
  );
}

export function checkCookieBanner() {
  for (const provider of Object.keys(SELECTORS)) {
    for (const selector of SELECTORS[provider]) {
      const element = document.querySelector(selector)

      if (element && isVisible(element)) {
        return true
      }
    }
  }

  return false
}