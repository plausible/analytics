import React from 'react'
import { MODES } from '../stats/behaviours/modes-context'
import * as api from '../api'
import { useSiteContext } from '../site-context'

export function FeatureSetupNotice({
  feature,
  title,
  info,
  callToAction,
  onHideAction
}) {
  const site = useSiteContext()
  const sectionTitle = MODES[feature].title

  const requestHideSection = () => {
    if (
      window.confirm(
        `Are you sure you want to hide ${sectionTitle}? You can make it visible again in your site settings later.`
      )
    ) {
      api
        .mutation(`/api/${encodeURIComponent(site.domain)}/disable-feature`, {
          method: 'PUT',
          body: { feature: feature }
        })
        .then(() => onHideAction())
        .catch((error) => {
          if (!(error instanceof api.ApiError)) {
            throw error
          }
        })
    }
  }

  function renderCallToAction() {
    return (
      <a
        href={callToAction.link}
        className="flex items-center gap-x-1.5 ml-2 sm:ml-4 button px-2 sm:px-4"
      >
        <p className="text-xs sm:text-sm font-medium">{callToAction.action}</p>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          strokeWidth={1.5}
          stroke="currentColor"
          className="size-4"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M4.5 12h15m0 0l-6.75-6.75M19.5 12l-6.75 6.75"
          />
        </svg>
      </a>
    )
  }

  function renderHideButton() {
    return (
      <button
        onClick={requestHideSection}
        className="inline-block px-2 sm:px-4 py-2 font-medium leading-5 rounded-md border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 hover:text-gray-900 dark:hover:bg-gray-600 dark:hover:text-white hover:shadow-sm transition-all duration-150"
      >
        Hide this report
      </button>
    )
  }

  return (
    <div className="size-full flex items-center justify-center">
      <div className="py-3 max-w-2xl">
        <div className="text-center text-pretty mt-2 text-gray-800 dark:text-gray-200 font-medium text-pretty">
          {title}
        </div>

        <div className="text-center text-pretty mt-4 font-small text-sm text-gray-500 dark:text-gray-200 text-pretty">
          {info}
        </div>

        <div className="text-xs sm:text-sm flex my-6 justify-center">
          {renderHideButton()}
          {renderCallToAction()}
        </div>
      </div>
    </div>
  )
}
