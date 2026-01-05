import React, { useRef, useEffect } from 'react'
import { ExclamationCircleIcon } from '@heroicons/react/24/outline'
import FadeIn from '../fade-in'
import { useQueryContext } from '../query-context'
import { Tooltip } from '../util/tooltip'

export default function ImportedQueryUnsupportedWarning({
  loading,
  skipImportedReason,
  altCondition,
  message
}) {
  const { query } = useQueryContext()
  const portalRef = useRef(null)
  const tooltipMessage =
    message || 'Imported data is excluded due to applied filters'
  const show =
    query &&
    query.with_imported &&
    skipImportedReason === 'unsupported_query' &&
    query.period !== 'realtime'

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
