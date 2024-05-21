import React from "react";
import { ExclamationCircleIcon } from '@heroicons/react/24/outline'

export default function ImportedQueryUnsupportedWarning({condition}) {
  if (condition) {
    return (
      <span tooltip="Imported data is excluded due to applied filters">
        <ExclamationCircleIcon className="w-6 h-6" />
      </span>
    )
  } else {
    return null
  }
}