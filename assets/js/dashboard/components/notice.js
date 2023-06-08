import React from "react"
import { EyeSlashIcon } from '@heroicons/react/20/solid'
import { sectionTitles } from "../stats/behaviours"
import * as api from '../api'

export function FeatureSetupNotice({ site, feature, shortFeatureName, title, info, settingsLink, onHideAction }) {
  const sectionTitle = sectionTitles[feature]

  const requestHideSection = () => {
    if (window.confirm(`Are you sure you want to hide ${sectionTitle}? You can make it visible again in your site settings later.`)) {
      api.get(`/api/${encodeURIComponent(site.domain)}/disable-feature`, {}, { feature: feature })
        .then((resp) => {
          if (resp === 'ok') { onHideAction() }
        })
    }
  }

  function setupButton() {
    return (
      <a href={settingsLink} className="ml-2 sm:ml-4 button px-2 sm:px-4">
        <p className="flex flex-col justify-center text-xs sm:text-sm">Set up {shortFeatureName}</p>
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="ml-2 w-5 h-5">
          <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12h15m0 0l-6.75-6.75M19.5 12l-6.75 6.75" />
        </svg>
      </a>
    )
  }

  function hideButton() {
    return (
      <button
        onClick={requestHideSection}
        className="inline-block px-2 sm:px-4 py-2 border border-gray-300 dark:border-gray-500 leading-5 rounded-md text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 transition ease-in-out duration-150">
        Hide this report
      </button>
    )
  }

  return (
    <div className="sm:mx-32 mt-6 mb-3" >
      <div className="py-3">
        <div className="text-center mt-2 text-gray-800 dark:text-gray-200">
          {title}
        </div>

        <div className="text-justify mt-4 font-small text-sm text-gray-500 dark:text-gray-200">
          {info}
        </div>

        <div className="text-xs sm:text-sm flex my-6 justify-center">
          {hideButton()}
          {setupButton()}
        </div>
      </div>
    </div>
  )
}