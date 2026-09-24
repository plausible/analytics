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
import { DashboardState } from '../../dashboard-state'
import { hasConversionGoalFilter, hasPageFilter } from '../../util/filters'
import { trackEvent } from '../../dogfood'
import { Tooltip } from '../../util/tooltip'
import { useBodyPortalRef } from '../breakdowns'

export enum ExportStatus {
  idle = 'idle',
  exporting = 'exporting',
  error = 'error'
}

function durationBucket(ms: number): string {
  const s = ms / 1000
  if (s >= 20) return '20s+'
  const floor = Math.floor(s / 2) * 2
  return `${floor}-${floor + 2}s`
}

function dogfoodTrackCsvExport(
  isSuccess: boolean,
  dashboardState: DashboardState,
  startedAt: number
): void {
  trackEvent('csv_export', {
    is_success: String(isSuccess),
    goal_filter: String(hasConversionGoalFilter(dashboardState)),
    page_filter: String(hasPageFilter(dashboardState)),
    period: dashboardState.period,
    duration_bucket: durationBucket(performance.now() - startedAt)
  })
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
    const startedAt = performance.now()

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
      dogfoodTrackCsvExport(true, dashboardState, startedAt)
    } catch {
      setExportStatus(ExportStatus.error)
      dogfoodTrackCsvExport(false, dashboardState, startedAt)
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
