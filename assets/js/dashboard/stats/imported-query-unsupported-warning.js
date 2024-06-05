import React from "react";
import { ExclamationCircleIcon } from '@heroicons/react/24/outline'

export default function ImportedQueryUnsupportedWarning({query, skipImportedReason, alt_condition, message}) {
  const tooltipMessage = message || "Imported data is excluded due to applied filters"

  if (query && query.with_imported && skipImportedReason === "unsupported_query") {
    return (
      <span tooltip={tooltipMessage}>
        <ExclamationCircleIcon className="w-6 h-6 dark:text-gray-100" />
      </span>
    )
  } else if (alt_condition) {
    return (
      <span tooltip={tooltipMessage}>
        <ExclamationCircleIcon className="w-6 h-6 dark:text-gray-100" />
      </span>
    )
  } else {
    return null
  }
}