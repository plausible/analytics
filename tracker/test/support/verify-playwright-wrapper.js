import { compileFile } from '../../compiler/index.js'
import variantsFile from '../../compiler/variants.json' with { type: 'json' }

const VARIANT = variantsFile.manualVariants.find(variant => variant.name === 'verifier-v1.js')

export default async function verify(page, context) {
  const {url, expectedDataDomain} = context
  const debug = context.debug ? true : false

  const verifierCode = await compileFile(VARIANT, { returnCode: true })

  await page.goto(url)
  await page.addScriptTag({ content: verifierCode })

  return await page.evaluate(async ({expectedDataDomain, debug}) => {
    return await window.verifyPlausibleInstallation(expectedDataDomain, debug)
  }, {expectedDataDomain, debug})
}
