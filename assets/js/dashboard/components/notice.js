import React from "react"
import { EyeSlashIcon } from '@heroicons/react/20/solid'
import { sectionTitles } from "../stats/behaviours"
import * as api from '../api'

export function FeatureSetupNotice({site, feature, shortFeatureName, title, info, settingsLink, onHideAction}) {
  const sectionTitle = sectionTitles[feature]

  const requestHideSection = () => {
    if (window.confirm(`Are you sure you want to hide ${sectionTitle}? You can make it visible again in your site settings later.`)) {
      api.get(`/api/${encodeURIComponent(site.domain)}/disable-feature`, {}, { feature: feature })
      onHideAction()
    }
  }

  function setupButton() {
    return (
      <a href={settingsLink} className="ml-4 button">
        <p>Set up {shortFeatureName}</p>
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
        className="inline-block px-4 py-2 border border-gray-300 dark:border-gray-500 text-sm leading-5 font-medium rounded-md text-red-700 bg-white dark:bg-gray-850 dark:hover:bg-gray-800 hover:text-red-500 dark:hover:text-red-400 transition ease-in-out duration-150">
          Hide this report
      </button>
    )
  }

  return (
    <div className="md:mx-32 mt-6 mb-3 shadow-lg dark:bg-gray-850 rounded-md" >
      <div className="px-8 py-3">
        <div className="text-center mt-2 text-lg text-gray-800 dark:text-gray-200">
          {title}
        </div>

        <div className="text-justify mt-4 font-small text-sm text-gray-500">
          {info}
        </div>

        <div className="flex my-6 justify-center">
          {hideButton()}
          {setupButton()}
        </div>
      </div>
    </div>
  )
}