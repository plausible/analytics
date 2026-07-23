import React, { useEffect, useRef, useState } from 'react'
import { XMarkIcon } from '@heroicons/react/24/outline'
import { useSiteContext } from './site-context'
import { useCurrentVisitorsContext } from './current-visitors-context'

type CTAStorageState = 'pending' | 'visible'

function getStorageKey(domain: string) {
  return `email_reports_cta_${domain}`
}

// CTA for configuring weekly email reports
//
// Renders only once, as soon as the first pageview lands. This can happen:
//
//   1. Automatically, when the dashboard stays open -- relying on the value
//      of current-visitors changing to something other than 0.
//
//   2. Dashboard is refreshed and showing data for the very first time.
//
// Case 2 is the tricky one. By the time of the refresh, `site.statsBegin`
// is already set, so that value alone can't distinguish "stats just
// started" from "this site has always had stats".
// 
// The sessionStorage entry closes that gap -- it's stamped 'pending' the
// moment stats are still absent, so a later reload can still recognize the
// transition. It is only ever stamped while stats are absent, so established
// sites never pick it up and can't retrigger the CTA.
// 
// Once shown, the same entry is stamped 'visible', so a refresh mid-display
// resumes the CTA instead of re-deciding from scratch -- but only for three
// seconds -- past that, the sessionStorage entry clears itself out and a
// refresh won't bring the CTA back.
export function EmailReportsCTABanner() {
  const site = useSiteContext()
  const currentVisitors = useCurrentVisitorsContext()
  const hasStats = !!site.statsBegin
  const storageKey = getStorageKey(site.domain)

  const hasTriggeredRef = useRef(false)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if (!hasStats && sessionStorage.getItem(storageKey) !== 'visible') {
      const state: CTAStorageState = 'pending'
      sessionStorage.setItem(storageKey, state)
    }
  }, [hasStats, storageKey])

  useEffect(() => {
    if (hasTriggeredRef.current) {
      return
    }

    const storedState = sessionStorage.getItem(storageKey)

    if (storedState === 'visible') {
      hasTriggeredRef.current = true
      setVisible(true)
      return
    }

    const firstPageviewJustLanded = hasStats
      ? storedState === 'pending'
      : !!currentVisitors

    if (!firstPageviewJustLanded) {
      return
    }

    hasTriggeredRef.current = true
    const state: CTAStorageState = 'visible'
    sessionStorage.setItem(storageKey, state)
    setVisible(true)
  }, [hasStats, currentVisitors, storageKey])

  useEffect(() => {
    if (!visible) {
      return
    }

    const timeout = setTimeout(() => {
      sessionStorage.removeItem(storageKey)
    }, 3000)

    return () => clearTimeout(timeout)
  }, [visible, storageKey])

  if (!visible) {
    return null
  }

  function dismiss() {
    sessionStorage.removeItem(storageKey)
    setVisible(false)
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
        href={`/${encodeURIComponent(site.domain)}/settings/email-reports`}
        onClick={dismiss}
      >
        Get weekly traffic reports by email →
      </a>
    </div>
  )
}
