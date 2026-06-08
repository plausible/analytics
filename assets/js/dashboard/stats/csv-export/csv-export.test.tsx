import React from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import { CsvExportV2 } from './csv-export'

const exportButton = () => screen.getByRole('button', { name: /export stats/i })

function renderCsvExport({
  exporting,
  setExporting
}: {
  exporting: boolean
  setExporting: () => void
}) {
  render(<CsvExportV2 exporting={exporting} setExporting={setExporting} />, {
    wrapper: (props) => (
      <TestContextProviders
        {...props}
        siteOptions={{ flags: { dashboard_csv_export_v2: true } }}
      />
    )
  })
}

test('shows spinner while exporting', () => {
  renderCsvExport({ exporting: true, setExporting: jest.fn() })
  expect(exportButton().querySelector('.animate-spin')).toBeInTheDocument()
})

test('does not start a second export while one is in progress', async () => {
  const setExporting = jest.fn()
  renderCsvExport({ exporting: true, setExporting })

  await userEvent.click(exportButton())

  expect(setExporting).not.toHaveBeenCalled()
})
