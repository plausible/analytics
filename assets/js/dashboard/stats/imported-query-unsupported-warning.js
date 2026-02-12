import React, { useRef, useEffect } from 'react'
import { ExclamationCircleIcon } from '@heroicons/react/24/outline'
import FadeIn from '../fade-in'
import { useDashboardStateContext } from '../dashboard-state-context'
import { Tooltip } from '../util/tooltip'

export default function ImportedQueryUnsupportedWarning({
  loading,
  skipImportedReason,
  altCondition,
  message
}) {
  const { dashboardState } = useDashboardStateContext()
  const portalRef = useRef(null)
  const tooltipMessage =
    message || 'Imported data is excluded due to applied filters'
  const show =
    dashboardState &&
    dashboardState.with_imported &&
    skipImportedReason === 'unsupported_query' &&
    dashboardState.period !== 'realtime'

  useEffect(() => {
    if (typeof document !== 'undefined') {
      portalRef.current = document.body
    }
  }, [])

  if (show || altCondition) {
    return (
      <FadeIn show={!loading} className="h-4.5">
        <Tooltip info={tooltipMessage} containerRef={portalRef}>
          <ExclamationCircleIcon className="mb-1 size-4.5 text-gray-500 dark:text-gray-400" />
        </Tooltip>
      </FadeIn>
    )
  } else {
    return null
  }
}
