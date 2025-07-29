import { compileFile } from '../../compiler/index.js'
import variantsFile from '../../compiler/variants.json' with { type: 'json' }
import { Page } from '@playwright/test'
import { VerifyV2Args, VerifyV2Result } from './types'

const VERIFIER_V1_JS_VARIANT = variantsFile.manualVariants.find(
  (variant) => variant.name === 'verifier-v1.js'
)
const VERIFIER_V2_JS_VARIANT = variantsFile.manualVariants.find(
  (variant) => variant.name === 'verifier-v2.js'
)
const DETECTOR_JS_VARIANT = variantsFile.manualVariants.find(
  (variant) => variant.name === 'detector.js'
)

export async function executeVerifyV2(
  page: Page,
  { debug, responseHeaders, timeoutMs, cspHostToCheck }: VerifyV2Args
): Promise<VerifyV2Result> {
  const verifierCode = (await compileFile(VERIFIER_V2_JS_VARIANT, {
    returnCode: true
  })) as string

  try {
    await page.evaluate(verifierCode)

    return await page.evaluate(
      async ({ responseHeaders, debug, timeoutMs, cspHostToCheck }) => {
        return await (window as any).verifyPlausibleInstallation({
          responseHeaders,
          debug,
          timeoutMs,
          cspHostToCheck
        })
      },
      { responseHeaders, debug, timeoutMs, cspHostToCheck }
    )
  } catch (error) {
    return {
      data: {
        completed: false,
        error: {
          message: error?.message ?? JSON.stringify(error)
        }
      }
    }
  }
}

export async function verifyV1(page, context) {
  const { url, expectedDataDomain } = context
  const debug = context.debug ? true : false

  const verifierCode = await compileFile(VERIFIER_V1_JS_VARIANT, {
    returnCode: true
  })

  await page.goto(url)
  await page.evaluate(verifierCode)

  return await page.evaluate(
    async ({ expectedDataDomain, debug }) => {
      return await (window as any).verifyPlausibleInstallation(
        expectedDataDomain,
        debug
      )
    },
    { expectedDataDomain, debug }
  )
}

export async function detect(page, context) {
  const { url, detectV1 } = context
  const debug = context.debug ? true : false

  const detectorCode = await compileFile(DETECTOR_JS_VARIANT, {
    returnCode: true
  })

  await page.goto(url)
  await page.evaluate(detectorCode)

  return await page.evaluate(
    async ({ detectV1, debug }) => {
      return await (window as any).scanPageBeforePlausibleInstallation(
        detectV1,
        debug
      )
    },
    { detectV1, debug }
  )
}
