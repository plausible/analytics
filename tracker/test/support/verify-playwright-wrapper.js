import path from 'node:path'
import { fileURLToPath } from 'url'
import fs from 'node:fs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const verifierScript = fs.readFileSync(path.join(__dirname, '../../verifier/verifier.js'), 'utf8')

export default async function verify(page, context) {
  const {url, expectedDataDomain} = context
  const debug = context.debug ? true : false

  await page.goto(url)
  await page.addScriptTag({ content: verifierScript })

  return await page.evaluate(async ({expectedDataDomain, debug}) => {
    return await window.verifyPlausibleInstallation(expectedDataDomain, debug)
  }, {expectedDataDomain, debug})
}