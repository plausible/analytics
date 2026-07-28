import React, { useState } from 'react'
import { XMarkIcon } from '@heroicons/react/24/outline'
import { useSiteContext } from './site-context'
import * as api from './api'

// CTA for configuring weekly email reports. It displays when the
// dashboard is loaded for the very first time, having actual data
// (i.e. site.onboarding_status == "first_pageview"). The CTA will
// remain visible until either:
//
// 1) it's dismissed by any site member that sees it --
//    Notifies the backend to advance the site onboarding status via
//    a HTTP request.
//
// 2) the CTA is clicked by any site member that sees it --
//    The link to /:domain/settings/email-reports includes a query
//    parameter telling the controller action to advance the site's
//    onboarding status.
export function EmailReportsCTABanner() {
  const site = useSiteContext()
  const [visible, setVisible] = useState(site.showEmailReportsCta)

  if (!visible) {
    return null
  }

  function dismiss() {
    setVisible(false)

    api
      .mutation(`/api/${encodeURIComponent(site.domain)}/complete-onboarding`, {
        method: 'PUT',
        body: {}
      })
      .catch((error) => {
        if (!(error instanceof api.ApiError)) {
          throw error
        }
      })
  }

  return (
    <div
      role="alert"
      className="text-md relative mb-4 rounded-md bg-indigo-100/60 p-4 text-center font-medium dark:bg-indigo-900/40"
    >
      <button
        type="button"
        aria-label="Dismiss"
        className="absolute right-2 top-2 z-10 rounded p-1 text-gray-800 hover:text-gray-600 dark:text-gray-100/60 dark:hover:text-gray-100/70"
        onClick={dismiss}
      >
        <XMarkIcon className="size-4" />
      </button>
      <span className="mr-1 text-base">🎉</span>
      <span className="text-gray-900 dark:text-gray-100">
        Your first pageview has landed!
      </span>{' '}
      <a
        className="plausible-event-name=Weekly+Email+Note+Click text-indigo-600 hover:text-indigo-700 dark:text-indigo-500 dark:hover:text-indigo-400 transition-colors duration-150"
        href={`/${encodeURIComponent(site.domain)}/settings/email-reports?cta_clicked=true`}
        onClick={() => setVisible(false)}
      >
        Get weekly traffic reports by email →
      </a>
    </div>
  )
}
