import React from 'react'
import { useSiteContext } from '../../site-context'
import { popover } from '../../components/popover'
import classNames from 'classnames'
import { Spinner } from '../../components/icons'
import {
  ArrowDownTrayIcon,
  ExclamationCircleIcon
} from '@heroicons/react/24/outline'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useGraphIntervalContext } from '../graph/graph-interval-context'
import { createCsvExportRequestBody } from './csv-export-body'
import * as api from '../../api'
import { DateRange } from '../../stats-query'
import { Tooltip } from '../../util/tooltip'
import { useBodyPortalRef } from '../breakdowns'

export enum ExportStatus {
  idle = 'idle',
  exporting = 'exporting',
  error = 'error'
}

export function CsvExport({
  exportStatus,
  setExportStatus
}: {
  exportStatus: ExportStatus
  setExportStatus: (v: ExportStatus) => void
}) {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const { selectedInterval } = useGraphIntervalContext()

  const canStartExport = exportStatus === ExportStatus.idle

  const startExport = async () => {
    if (!canStartExport) return
    setExportStatus(ExportStatus.exporting)

    try {
      const body = createCsvExportRequestBody(dashboardState, selectedInterval)
      const blob = await api.csvExport(site, body)
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = constructFilename(site.domain, body.date_range)
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
      setExportStatus(ExportStatus.idle)
    } catch {
      setExportStatus(ExportStatus.error)
    }
  }

  return (
    <button
      onClick={startExport}
      className={classNames(
        popover.items.classNames.navigationLink,
        popover.items.classNames.hoverLink,
        !canStartExport && '!cursor-default'
      )}
    >
      <span className="text-sm">Export stats</span>
      {exportStatus === ExportStatus.exporting ? (
        <Spinner className="animate-spin size-4 text-indigo-500" />
      ) : exportStatus === ExportStatus.error ? (
        <ExportFailedBubble />
      ) : (
        <ArrowDownTrayIcon className="size-4 stroke-2" />
      )}
    </button>
  )
}

function ExportFailedBubble() {
  const portalRef = useBodyPortalRef()
  return (
    <Tooltip info={'Export failed'} containerRef={portalRef}>
      <ExclamationCircleIcon
        data-testid="export-error-icon"
        className="size-4 text-gray-500 dark:text-gray-400"
      />
    </Tooltip>
  )
}

function constructFilename(domain: string, dateRange: DateRange) {
  const dateRangeText = Array.isArray(dateRange)
    ? `${dateRange[0]} to ${dateRange[1]}`
    : dateRange
  return `Plausible export ${domain} ${dateRangeText} .zip`
}
