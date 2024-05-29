import React from "react";
import { ExclamationCircleIcon } from '@heroicons/react/24/outline'

export default function ImportedQueryUnsupportedWarning({condition, message}) {
  const tooltipMessage = message || "Imported data is excluded due to applied filters"
  
  if (condition) {
    return (
      <span tooltip={tooltipMessage}>
        <ExclamationCircleIcon className="w-6 h-6" />
      </span>
    )
  } else {
    return null
  }
}