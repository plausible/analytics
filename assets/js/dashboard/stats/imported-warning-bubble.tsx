import React from 'react'
import { ExclamationCircleIcon } from '@heroicons/react/24/outline'
import { Tooltip } from '../util/tooltip'
import { useBodyPortalRef } from './breakdowns'
import { QueryApiResponse } from '../api'

export default function ImportedWarningBubble({
  queryApiResponse,
  message
}: {
  queryApiResponse: QueryApiResponse | null
  message?: string
}) {
  const importsSkipReason = queryApiResponse?.meta?.imports_skip_reason
  const isRealtime = queryApiResponse?.extraContext.isRealtime

  const tooltipMessage =
    importsSkipReason === 'unsupported_query' && !isRealtime
      ? (message ?? 'Imported data is excluded due to applied filters')
      : null

  return tooltipMessage ? <WarningBubble message={tooltipMessage} /> : null
}

/**
 * Renders an imported warning bubble for "Funnels" and "Explore" tabs.
 * Currently, while the funnel and exploration queries silently ignore
 * everything related to imports, we should still let the user know that
 * imports are not included in those reports. Therefore, we rely on the
 * Top Stats response (i.e. the importedDataInView state) to know whether
 * imported data is in range, and if so, we render the warning bubble.
 */
export function FunnelsApiImportedWarningBubble({
  importedDataInView
}: {
  importedDataInView?: boolean
}) {
  return importedDataInView ? (
    <WarningBubble message="Imported data is unavailable in this view" />
  ) : null
}

function WarningBubble({ message }: { message: string }) {
  const portalRef = useBodyPortalRef()
  return (
    <Tooltip info={message} containerRef={portalRef}>
      <ExclamationCircleIcon className="mb-1 size-4.5 text-gray-500 dark:text-gray-400" />
    </Tooltip>
  )
}
