import React from "react";
import { ExclamationCircleIcon } from '@heroicons/react/24/outline'
import FadeIn from "../fade-in";

export default function ImportedQueryUnsupportedWarning({query, loading, skipImportedReason, altCondition, message}) {
  const tooltipMessage = message || "Imported data is excluded due to applied filters"
  const show = query && query.with_imported && skipImportedReason === "unsupported_query" && query.period !== 'realtime'

  if (show || altCondition) {
    return (
      <FadeIn show={!loading} className="h-6">
        <span tooltip={tooltipMessage}>
          <ExclamationCircleIcon className="w-6 h-6 dark:text-gray-100" />
        </span>
      </FadeIn>
    )
  } else {
    return null
  }
}