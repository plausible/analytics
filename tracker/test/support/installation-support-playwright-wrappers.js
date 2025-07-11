import { compileFile } from '../../compiler/index.js'
import variantsFile from '../../compiler/variants.json' with { type: 'json' }

const VERIFIER_V1_JS_VARIANT = variantsFile.manualVariants.find(variant => variant.name === 'verifier-v1.js')
const DETECTOR_JS_VARIANT = variantsFile.manualVariants.find(variant => variant.name === 'detector.js')

export async function verify(page, context) {
  const {url, expectedDataDomain} = context
  const debug = context.debug ? true : false

  const verifierCode = await compileFile(VERIFIER_V1_JS_VARIANT, { returnCode: true })

  await page.goto(url)
  await page.evaluate(verifierCode)

  return await page.evaluate(async ({expectedDataDomain, debug}) => {
    return await window.verifyPlausibleInstallation(expectedDataDomain, debug)
  }, {expectedDataDomain, debug})
}

export async function detect(page, context) {
  const {url, detectV1} = context
  const debug = context.debug ? true : false

  const detectorCode = await compileFile(DETECTOR_JS_VARIANT, { returnCode: true })

  await page.goto(url)
  await page.evaluate(detectorCode)

  return await page.evaluate(async ({detectV1, debug}) => {
    return await window.scanPageBeforePlausibleInstallation(detectV1, debug)
  }, {detectV1, debug})
}
