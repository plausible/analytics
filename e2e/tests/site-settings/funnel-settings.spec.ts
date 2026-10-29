import { test, expect } from '@playwright/test'
import {
  setupSite,
  populateStats,
  getFunnel,
  addGoal,
  addFunnel
} from '../fixtures'
import { expectLiveViewConnected } from '../test-utils'

test.describe('funnel settings', () => {
  test('form integration tests', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        { user_id: 123, name: 'Hello World', timestamp: { hoursAgo: 60 } },
        { user_id: 123, name: 'Plausible', timestamp: { hoursAgo: 50 } },
        { user_id: 123, name: 'Another World', timestamp: { hoursAgo: 45 } }
      ]
    })

    await page.goto(`/${domain}/settings/funnels`, { waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await test.step('search reacts to the input the user types in', async () => {
      await page.getByRole('button', { name: 'Add funnel' }).click()

      await expect(page.locator('#funnel-form')).toBeVisible()

      await page.locator('#step-1 input').fill('hello')

      await expect(
        page
          .locator('#step-1 .input-picker-dropdown-option')
          .getByText('Hello World')
      ).toBeVisible()

      await page.locator('#step-1 input').fill('hello')

      await expect(
        page
          .locator('#step-1 .input-picker-dropdown-option')
          .getByText('Plausible')
      ).toBeVisible()

      // First escape press cancels focus on combobox input;
      // next one closes the modal.
      await page.keyboard.press('Escape')
      await page.keyboard.press('Escape')

      await expect(page.locator('#funnel-form')).toBeHidden()
    })

    await test.step('selecting option prefills input values', async () => {
      await page.getByRole('button', { name: 'Add funnel' }).click()

      await expect(page.locator('#funnel-form')).toBeVisible()

      await page.locator('#step-1 input').fill('another')

      await page
        .locator('#step-1 .input-picker-dropdown-option')
        .getByText('Another World')
        .click()

      await expect(page.locator('#step-1 input')).toHaveValue('Another World')

      await page.keyboard.press('Escape')
      await page.keyboard.press('Escape')

      await expect(page.locator('#funnel-form')).toBeHidden()
    })

    await test.step('selecting one option reduces suggestions in the other', async () => {
      await page.getByRole('button', { name: 'Add funnel' }).click()

      await expect(page.locator('#funnel-form')).toBeVisible()

      await page.locator('#step-1 input').fill('another')

      await page
        .locator('#step-1 .input-picker-dropdown-option')
        .getByText('Another World')
        .click()

      await page.locator('#step-2 input').fill('a')

      await expect(
        page
          .locator('#step-2 .input-picker-dropdown-option')
          .getByText('Another World')
      ).toBeHidden()

      await page.keyboard.press('Escape')
      await page.keyboard.press('Escape')

      await expect(page.locator('#funnel-form')).toBeHidden()
    })

    await test.step('removing one option alters suggestions for other', async () => {
      await page.getByRole('button', { name: 'Add funnel' }).click()

      await expect(page.locator('#funnel-form')).toBeVisible()

      await page.locator('a[phx-click=add-step]').click()

      await page.locator('#step-2 input').fill('hello')

      await page
        .locator('#step-2 .input-picker-dropdown-option')
        .getByText('Hello World')
        .click()

      await page.locator('#step-1 input').fill('hello')

      await expect(
        page
          .locator('#step-1 .input-picker-dropdown-option')
          .getByText('Hello World')
      ).toBeHidden()

      await page.locator('#remove-step-2').click()

      await page.locator('#step-1 input').fill('hello')

      await expect(
        page
          .locator('#step-1 .input-picker-dropdown-option')
          .getByText('Hello World')
      ).toBeVisible()

      await page.keyboard.press('Escape')
      await page.keyboard.press('Escape')

      await expect(page.locator('#funnel-form')).toBeHidden()
    })
  })

  test('save button saves a new funnel', async ({ page, request }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        {
          user_id: 123,
          name: 'pageview',
          pathname: '/page1',
          timestamp: { hoursAgo: 60 }
        },
        {
          user_id: 123,
          name: 'Form: Submission',
          'meta.key': ['path'],
          'meta.value': ['/form-action/path'],
          timestamp: { hoursAgo: 50 }
        },
        {
          user_id: 123,
          name: 'pageview',
          pathname: '/page2',
          timestamp: { hoursAgo: 45 }
        }
      ]
    })

    await page.goto(`/${domain}/settings/funnels`, { waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await page.getByRole('button', { name: 'Add funnel' }).click()

    await expect(page.locator('#funnel-form')).toBeVisible()

    await expect(page.locator('button#save')).toBeDisabled()

    await page.locator('#step-1 input').fill('page')

    await page
      .locator('#step-1 .input-picker-dropdown-option')
      .getByText('Visit /page1')
      .click()

    await expect(page.locator('#step-1 input')).toHaveValue('Visit /page1')

    await page.locator('#step-2 input').click()

    await page
      .locator('#step-2 .input-picker-dropdown-option')
      .getByText('Form: Submission')
      .click()

    await page.locator('input#funnel_name').fill('First funnel')

    await expect(page.locator('button#save')).toBeEnabled()

    await page.locator('button#save').click()

    await expect(page.locator('#funnel-form')).toBeHidden()

    await expect(page.locator('#funnel-settings-main table')).toContainText(
      'First funnel'
    )

    const {
      name: funnel_name,
      steps: [step1, step2]
    } = await getFunnel({ request, domain, name: 'First funnel' })

    expect(funnel_name).toBe('First funnel')
    expect(step1.id).toBe(0) // dynamic step
    expect(step1.page_path).toBe('/page1')
    expect(step2.id).toBeGreaterThan(0) // static step
    expect(step2.event_name).toBe('Form: Submission')
  })

  test('clicking save after editing the funnel updates it', async ({
    page,
    request
  }) => {
    const { domain } = await setupSite({ page, request })

    await addGoal({
      request,
      domain,
      params: { page_path: '/page1' }
    })

    await addGoal({
      request,
      domain,
      params: { event_name: 'Form: Submission' }
    })

    await populateStats({
      request,
      domain,
      events: [
        {
          user_id: 123,
          name: 'pageview',
          pathname: '/page1',
          timestamp: { hoursAgo: 60 }
        },
        {
          user_id: 123,
          name: 'Form: Submission',
          'meta.key': ['path'],
          'meta.value': ['/form-action/path'],
          timestamp: { hoursAgo: 50 }
        },
        {
          user_id: 123,
          name: 'pageview',
          pathname: '/page2',
          timestamp: { hoursAgo: 45 }
        },
        {
          user_id: 124,
          name: 'pageview',
          pathname: '/page1',
          timestamp: { hoursAgo: 60 }
        },
        {
          user_id: 124,
          name: 'pageview',
          pathname: '/page2',
          timestamp: { hoursAgo: 45 }
        }
      ]
    })

    await addFunnel({
      request,
      domain,
      name: 'Existing funnel',
      steps: ['Visit /page1', { page_path: '/page2' }]
    })

    await page.goto(`/${domain}/settings/funnels`, { waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await page.locator('button[phx-click=edit-funnel]').click()

    await expect(page.locator('#funnel-form')).toBeVisible()

    await page.locator('#step-2 input').fill('form')

    await page
      .locator('#step-2 .input-picker-dropdown-option')
      .getByText('Form: Submission')
      .click()

    await expect(page.locator('#step-2 input')).toHaveValue('Form: Submission')

    await page.locator('input#funnel_name').fill('Updated funnel')

    await expect(page.locator('button#save')).toBeEnabled()

    await page.locator('button#save').click()

    await expect(page.locator('#funnel-form')).toBeHidden()

    const {
      name: funnel_name,
      steps: [step1, step2]
    } = await getFunnel({ request, domain, name: 'Updated funnel' })

    expect(funnel_name).toBe('Updated funnel')
    expect(step1.id).toBeGreaterThan(0) // static step
    expect(step1.page_path).toBe('/page1')
    expect(step2.id).toBeGreaterThan(0) // static step
    expect(step2.event_name).toBe('Form: Submission')
  })

  test('funnel gets evaluated on every select, assuming a second has passed between selections', async ({
    page,
    request
  }) => {
    const { domain } = await setupSite({ page, request })

    await populateStats({
      request,
      domain,
      events: [
        {
          user_id: 123,
          name: 'pageview',
          pathname: '/page1',
          timestamp: { hoursAgo: 60 }
        },
        {
          user_id: 123,
          name: 'Form: Submission',
          'meta.key': ['path'],
          'meta.value': ['/form-action/path'],
          timestamp: { hoursAgo: 50 }
        },
        {
          user_id: 123,
          name: 'pageview',
          pathname: '/page2',
          timestamp: { hoursAgo: 45 }
        }
      ]
    })

    await page.goto(`/${domain}/settings/funnels`, { waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await page.getByRole('button', { name: 'Add funnel' }).click()

    await expect(page.locator('#funnel-form')).toBeVisible()

    await page.locator('#step-1 input').click()

    await page.locator('#step-1 .input-picker-dropdown-option').first().click()

    await expect(page.locator('#step-1 input')).not.toHaveValue('')

    await page.locator('#step-2 input').click()

    await page.locator('#step-2 .input-picker-dropdown-option').first().click()

    await expect(page.locator('#step-2 input')).not.toHaveValue('')

    await expect(page.locator('#step-eval-0')).toHaveText('Visitors: 1')
    await expect(page.locator('#step-eval-1')).toHaveText('Dropoff: 100%')
    await expect(page.locator('#funnel-eval')).toHaveText(
      'Last month conversion rate: 0%'
    )
  })

  test('scroll goal can be picked for a matching pageview event from the previous step', async ({
    page,
    request
  }) => {
    const { domain } = await setupSite({ page, request })

    await addGoal({
      request,
      domain,
      params: {
        page_path: '/page1',
        scroll_threshold: 90,
        display_name: 'Scroll 90% on /page1'
      }
    })

    await populateStats({
      request,
      domain,
      events: [
        {
          user_id: 123,
          name: 'pageview',
          pathname: '/page1',
          timestamp: { minutesAgo: 1500 }
        },
        {
          user_id: 123,
          name: 'engagement',
          pathname: '/page1',
          scroll_depth: 90,
          timestamp: { minutesAgo: 1499 }
        },
        {
          user_id: 123,
          name: 'pageview',
          pathname: '/page2',
          timestamp: { minutesAgo: 1498 }
        }
      ]
    })

    await page.goto(`/${domain}/settings/funnels`, { waitUntil: 'commit' })
    await expectLiveViewConnected(page)

    await page.getByRole('button', { name: 'Add funnel' }).click()

    await expect(page.locator('#funnel-form')).toBeVisible()

    await page.locator('#step-1 input').click()

    await page
      .locator('#step-1 .input-picker-dropdown-option')
      .getByText('Visit /page1')
      .click()

    await expect(page.locator('#step-1 input')).toHaveValue('Visit /page1')

    await page.locator('#step-2 input').click()

    await expect(
      page
        .locator('#step-2 .input-picker-dropdown-option')
        .getByText('Scroll 90% on /page1')
    ).toBeVisible()
  })
})
