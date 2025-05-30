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
    await page.evaluate((c) => {
      window.init(c)
    }, { ...DEFAULT_CONFIG, ...config })
  }
}


test.describe('NPM package', () => {
  testPlausibleConfiguration({
    openPage,
    initPlausible: (page, config) => callInit(page, { ...DEFAULT_CONFIG, ...config }, 'window'),
    fixtureName: 'plausible-npm.html',
    fixtureTitle: 'Plausible NPM package tests'
  })
})
