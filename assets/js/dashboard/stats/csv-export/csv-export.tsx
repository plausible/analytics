import React, { useState } from 'react'
import { useSiteContext } from '../../site-context'
import { popover } from '../../components/popover'
import classNames from 'classnames'
import { Spinner } from '../../components/icons'
import { ArrowDownTrayIcon } from '@heroicons/react/24/outline'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useGraphIntervalContext } from '../graph/graph-interval-context'
import { createCsvExportRequestBody } from './csv-export-body'
import * as api from '../../api'

export function CsvExportV2() {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const { selectedInterval } = useGraphIntervalContext()

  const [exporting, setExporting] = useState(false)

  const startExport = async () => {
    setExporting(true)

    try {
      const body = createCsvExportRequestBody(dashboardState, selectedInterval)
      const blob = await api.csvExport(site, body)
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'plausible-export.zip'
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
    } finally {
      setExporting(false)
    }
  }

  return (
    <button
      onClick={startExport}
      className={classNames(
        popover.items.classNames.navigationLink,
        popover.items.classNames.hoverLink
      )}
    >
      <span className="text-sm">Export stats</span>
      {exporting ? (
        <Spinner className="animate-spin size-4 text-indigo-500" />
      ) : (
        <ArrowDownTrayIcon className="size-4 stroke-2" />
      )}
    </button>
  )
}
