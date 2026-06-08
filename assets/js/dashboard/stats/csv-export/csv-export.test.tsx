import React from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import { CsvExportV2, ExportStatus } from './csv-export'

const exportButton = () => screen.getByRole('button', { name: /export stats/i })

function renderCsvExport({
  exportStatus,
  setExportStatus
}: {
  exportStatus: ExportStatus
  setExportStatus: () => void
}) {
  render(
    <CsvExportV2
      exportStatus={exportStatus}
      setExportStatus={setExportStatus}
    />,
    {
      wrapper: (props) => (
        <TestContextProviders
          {...props}
          siteOptions={{ flags: { dashboard_csv_export_v2: true } }}
        />
      )
    }
  )
}

test('shows spinner while exporting', () => {
  renderCsvExport({
    exportStatus: ExportStatus.exporting,
    setExportStatus: jest.fn()
  })
  expect(exportButton().querySelector('.animate-spin')).toBeInTheDocument()
})

test('does not start a second export while one is in progress', async () => {
  const setExportStatus = jest.fn()
  renderCsvExport({ exportStatus: ExportStatus.exporting, setExportStatus })

  await userEvent.click(exportButton())

  expect(setExportStatus).not.toHaveBeenCalled()
})

test('shows error icon when export fails', () => {
  renderCsvExport({
    exportStatus: ExportStatus.error,
    setExportStatus: jest.fn()
  })

  expect(screen.getByTestId('export-error-icon')).toBeInTheDocument()
})
