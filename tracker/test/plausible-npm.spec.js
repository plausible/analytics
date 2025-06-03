/*
Tests for plausible-web.js script variant

Unlike in production, we're manually interpolating the script config in this file to
better test the script in isolation of the plausible codebase.
*/

import {
  expectPlausibleInAction,
  hideAndShowCurrentTab,
  metaKey,
  mockRequest,
  e as expecting
} from './support/test-utils'
import { test, expect } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'
import { testPlausibleConfiguration, callInit } from './shared-configuration-tests'

const DEFAULT_CONFIG = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

async function openPage(page, config, options = {}) {
  await page.goto("/plausible-npm.html")
  await page.waitForFunction('window.init !== undefined')

  if (!options.skipPlausibleInit) {
    await callInit(page, { ...DEFAULT_CONFIG, ...config }, 'window')
  }
}

test.describe('NPM package', () => {
  testPlausibleConfiguration({
    openPage,
    initPlausible: (page, config) => callInit(page, { ...DEFAULT_CONFIG, ...config }, 'window'),
    fixtureName: 'plausible-npm.html',
    fixtureTitle: 'Plausible NPM package tests'
  })

  test('does not support calling `init` without `domain`', async ({ page }) => {
    await openPage(page, {}, { skipPlausibleInit: true })
    await expect(async () => {
      await callInit(page, { hashBasedRouting: true }, 'window')
    }).rejects.toThrow("plausible.init(): domain argument is required")
  })

  test('does not support calling `init` with no configuration', async ({ page }) => {
    await openPage(page, {}, { skipPlausibleInit: true })
    await expect(async () => {
      await callInit(page, undefined, 'window')
    }).rejects.toThrow("plausible.init(): domain argument is required")
  })

  test('track throws if called before init', async ({ page }) => {
    await openPage(page, {}, { skipPlausibleInit: true })
    await expect(async () => {
      await page.evaluate(() => {
        window.track('pageview')
      })
    }).rejects.toThrow("plausible.track() can only be called after plausible.init()")
  })

  test('does not support calling `init` twice', async ({ page }) => {
    await openPage(page, {}, { skipPlausibleInit: true })
    await callInit(page, DEFAULT_CONFIG, 'window')
    await expect(async () => {
      await callInit(page, DEFAULT_CONFIG, 'window')
    }).rejects.toThrow("plausible.init() can only be called once")
  })
})
