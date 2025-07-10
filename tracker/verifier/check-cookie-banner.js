const SELECTORS = {
  // https://github.com/cavi-au/Consent-O-Matic/blob/master/rules/cookiebot.json
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