import { test, expect } from '@playwright/test'
import { setupSite, populateStats, register } from '../fixtures'
import { randomID } from '../test-utils'

test.use({ locale: 'en-GB' })

test('user can create annotations across granularities, edit, and delete them', async ({
  page,
  request
}) => {
  const user = {
    email: `site-owner-for-annotations-${randomID()}@example.com`,
    // name matters in this test
    name: 'J R.R. Smith',
    password: 'VeryStrongVerySecret'
  }
  await register({
    page,
    request,
    user
  })
  const { domain } = await setupSite({ page, request, user })

  await populateStats({
    request,
    domain,
    events: [
      {
        user_id: 0,
        name: 'pageview',
        pathname: '/',
        timestamp: '2026-04-01 00:00:00'
      },
      {
        user_id: 1,
        name: 'pageview',
        pathname: '/',
        timestamp: '2026-06-29 05:00:00'
      },
      {
        user_id: 2,
        name: 'pageview',
        pathname: '/',
        timestamp: '2026-06-29 10:00:00'
      }
    ]
  })

  await page.goto(`/${domain}?period=7d&date=2026-07-06&comparison=off`, {
    waitUntil: 'commit'
  })

  const mondayIn7d = page.getByTestId('graph-dot-series-1-bucket-0')
  const mondayMarker7d = page.getByTestId('annotation-marker-on-bucket-0')

  const tooltip = page.getByTestId('graph-tooltip')

  // inputs in create / edit modals
  const noteField = page.getByRole('textbox', { name: 'Note' })
  const saveButton = page.getByRole('button', { name: 'Save' })

  const siteNoteText = 'Company-wide: launch day'
  const personalNoteText = 'Feature available for 50% of customers'
  const updatedNoteText = 'Feature fully released (correction)'

  const personalNoteAttribution = 'Personal note • 29 Jun 10:00'
  const siteNoteAttribution = `${user.name} • 29 Jun`

  // Asserts the tooltip's annotation list matches provided list exactly
  const expectTooltipAnnotations = async (
    expected: Array<{ note: string; attribution: string }>
  ) => {
    const rows = tooltip.locator('div.group')
    await expect(rows).toHaveCount(expected.length)
    for (const [i, { note, attribution }] of expected.entries()) {
      const row = rows.nth(i)
      await expect(row).toContainText(note)
      await expect(row.getByText(attribution, { exact: true })).toBeVisible()
    }
  }

  // Needed because the tests expect a particular graph interval
  const setGraphInterval = async (label: 'Hours' | 'Days' | 'Months') => {
    await page.getByTestId('dashboard-options-menu').click()
    await page.getByRole('button', { name: label, exact: true }).click()
    await page.keyboard.press('Escape')
  }

  await test.step('in 7d view, create date-granularity site annotation on Monday', async () => {
    await setGraphInterval('Days')

    // hovered tooltip
    await mondayIn7d.hover()
    await expect(tooltip).toBeVisible()
    await expectTooltipAnnotations([])

    await expect(tooltip).toContainText('Click to view day')
    await expect(tooltip).toContainText('Right click for more actions')

    // persisted tooltip
    await mondayIn7d.click({ button: 'right' })
    await expect(tooltip).toBeVisible()

    await expect(tooltip.locator('button')).toContainText([
      'Add note',
      'View day'
    ])
    await tooltip.getByRole('button', { name: 'Add note' }).click()

    const createModalHeading = page.getByRole('heading', {
      name: 'Add note for Mon, 29 Jun',
      exact: true
    })
    await expect(createModalHeading).toBeVisible()

    await noteField.fill(siteNoteText)
    await page.getByRole('radio', { name: /Site note/ }).check()
    await saveButton.click()

    await expect(createModalHeading).toBeHidden()
    await expect(mondayMarker7d).toBeVisible()
  })

  await test.step('right-click Monday and zoom in via "View day"', async () => {
    await mondayIn7d.hover()
    await expectTooltipAnnotations([
      { note: siteNoteText, attribution: siteNoteAttribution }
    ])

    await mondayIn7d.click({ button: 'right' })

    await tooltip.getByRole('button', { name: 'View day' }).click()
    await expect(page).toHaveURL(/period=day&date=2026-06-29/)

    // Date-granularity annotations don't map to hour buckets — no marker in day view.
    await expect(page.getByTestId(/^annotation-marker-on-bucket-/)).toHaveCount(
      0
    )
  })

  await test.step('in day view, create minute-granularity personal annotation at 10:00', async () => {
    await setGraphInterval('Hours')

    const hour10InDay = page.getByTestId('graph-dot-series-1-bucket-10')
    await hour10InDay.hover()
    await hour10InDay.click({ button: 'right' })
    await expect(tooltip).toBeVisible()

    await tooltip.getByRole('button', { name: 'Add note' }).click()

    const createModalHeading = page.getByRole('heading', {
      name: 'Add note for Mon, 29 Jun at 10:00',
      exact: true
    })
    await expect(createModalHeading).toBeVisible()
    await expect(tooltip).toBeHidden()

    await noteField.fill(personalNoteText)
    await saveButton.click()

    await expect(createModalHeading).toBeHidden()
    await expect(
      page.getByTestId('annotation-marker-on-bucket-10')
    ).toBeVisible()
  })

  await test.step('zoom back out to 7d, both annotations are visible on Monday', async () => {
    await page.goBack({ waitUntil: 'commit' })
    await setGraphInterval('Days')

    await expect(mondayMarker7d).toBeVisible()

    const expectedOnMonday = [
      { note: personalNoteText, attribution: personalNoteAttribution },
      { note: siteNoteText, attribution: siteNoteAttribution }
    ]

    await mondayIn7d.hover()
    await expect(tooltip).toBeVisible()
    await expectTooltipAnnotations(expectedOnMonday)

    await mondayIn7d.click({ button: 'right' })
    await expect(tooltip).toBeVisible()
    await expectTooltipAnnotations(expectedOnMonday)
  })

  await test.step('edit personal annotation', async () => {
    const personalRow = tooltip.locator('div.group', {
      hasText: personalNoteText
    })
    await personalRow.hover()
    await personalRow.getByRole('button', { name: 'Edit note' }).click()

    const updateModalHeading = page.getByRole('heading', {
      name: 'Update note for Mon, 29 Jun at 10:00',
      exact: true
    })
    await expect(updateModalHeading).toBeVisible()
    await expect(tooltip).toBeHidden()
    await expect(noteField).toHaveValue(personalNoteText)

    await noteField.fill(updatedNoteText)
    await saveButton.click()

    await expect(updateModalHeading).toBeHidden()

    await mondayIn7d.hover()
    await mondayIn7d.click({ button: 'right' })
    await expectTooltipAnnotations([
      { note: updatedNoteText, attribution: personalNoteAttribution },
      { note: siteNoteText, attribution: siteNoteAttribution }
    ])
  })

  await test.step('delete personal annotation', async () => {
    const personalNote = tooltip.locator('div.group', {
      hasText: updatedNoteText
    })
    await personalNote.hover()
    await personalNote.getByRole('button', { name: 'Edit note' }).click()

    const updateModalHeading = page.getByRole('heading', {
      name: 'Update note for Mon, 29 Jun at 10:00',
      exact: true
    })
    await expect(updateModalHeading).toBeVisible()

    await page.getByRole('button', { name: 'Delete note' }).click()

    const deleteModalHeading = page.getByRole('heading', {
      name: `Delete personal note "${updatedNoteText}"?`,
      exact: true
    })
    await expect(deleteModalHeading).toBeVisible()
    await expect(updateModalHeading).toBeHidden()

    await page.getByRole('button', { name: 'Delete', exact: true }).click()

    await expect(deleteModalHeading).toBeHidden()
    await mondayIn7d.hover()
    await expectTooltipAnnotations([
      { note: siteNoteText, attribution: siteNoteAttribution }
    ])
    await expect(mondayMarker7d).toBeVisible()
  })

  await test.step('date annotations are shown for All period', async () => {
    await page.getByTestId('current-query-period').click()
    await page
      .getByTestId('query-period-picker')
      .getByRole('link', { name: 'All time' })
      .click()
    await expect(page).toHaveURL(/period=all/)

    const marker = page.getByTestId(/^annotation-marker-on-bucket-/)
    await expect(marker).toHaveCount(1)
    await expect(marker).toBeVisible()

    await setGraphInterval('Months')
    await page.getByText('June 2026', { exact: true }).hover()
    await expectTooltipAnnotations([
      { note: siteNoteText, attribution: siteNoteAttribution }
    ])
  })
})
