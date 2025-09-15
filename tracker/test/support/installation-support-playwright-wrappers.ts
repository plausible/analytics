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
  {
    responseHeaders,
    maxAttempts,
    timeoutBetweenAttemptsMs,
    ...functionContext
  }: VerifyV2Args & { maxAttempts: number; timeoutBetweenAttemptsMs: number }
): Promise<VerifyV2Result> {
  const verifierCode = (await compileFile(VERIFIER_V2_JS_VARIANT, {
    returnCode: true
  })) as string

  try {
    async function verify() {
      await page.evaluate(verifierCode) // injects window.verifyPlausibleInstallation
      return await page.evaluate(
        // @ts-expect-error - window.verifyPlausibleInstallation has been injected
        (c) => {
          return window.verifyPlausibleInstallation(c)
        },
        { ...functionContext, responseHeaders }
      )
    }

    let lastError
    for (let attempts = 1; attempts <= maxAttempts; attempts++) {
      try {
        const output = await verify()
        return {
          data: {
            ...output.data,
            attempts
          }
        }
      } catch (error) {
        lastError = error
        if (
          typeof error?.message === 'string' &&
          error.message.toLowerCase().includes('execution context')
        ) {
          await new Promise((resolve) =>
            setTimeout(resolve, timeoutBetweenAttemptsMs)
          )
          continue
        }
        throw error
      }
    }
    throw lastError
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
      // @ts-expect-error - window.verifyPlausibleInstallation has been injected
      return await window.verifyPlausibleInstallation(expectedDataDomain, debug)
    },
    { expectedDataDomain, debug }
  )
}

export async function detect(page, context) {
  const { url, detectV1, timeoutMs } = context
  const debug = context.debug ? true : false

  const detectorCode = await compileFile(DETECTOR_JS_VARIANT, {
    returnCode: true
  })

  await page.goto(url)
  await page.evaluate(detectorCode)

  return await page.evaluate(
    async (d) => {
      // @ts-expect-error - window.scanPageBeforePlausibleInstallation has been injected
      return await window.scanPageBeforePlausibleInstallation(d)
    },
    { detectV1, debug, timeoutMs }
  )
}
