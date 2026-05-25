import React from 'react'
import { ExclamationCircleIcon } from '@heroicons/react/24/outline'
import { Tooltip } from '../util/tooltip'
import { useBodyPortalRef } from './breakdowns'
import { QueryApiResponse } from '../api'

export default function ImportedWarningBubble({
  queryApiResponse
}: {
  queryApiResponse: QueryApiResponse | null
}) {
  const portalRef = useBodyPortalRef()

  const importsSkipReason = queryApiResponse?.meta?.imports_skip_reason
  const isRealtime = queryApiResponse?.extraContext.isRealtime

  const tooltipMessage =
    importsSkipReason === 'unsupported_query' && !isRealtime
      ? 'Imported data is excluded due to applied filters'
      : null

  if (tooltipMessage) {
    return (
      <Tooltip info={tooltipMessage} containerRef={portalRef}>
        <ExclamationCircleIcon className="mb-1 size-4.5 text-gray-500 dark:text-gray-400" />
      </Tooltip>
    )
  } else {
    return null
  }
}
