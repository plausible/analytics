import React from "react"
import { EyeSlashIcon } from '@heroicons/react/20/solid'
import { sectionTitles } from "../stats/behaviours"
import * as api from '../api'

export function featureSetupNotice(site, feature, opts) {
  const {title, info, hideNotice, docsLink} = opts
  const sectionTitle = sectionTitles[feature]

  const requestHideSection = () => {
    api.get(`/api/${encodeURIComponent(site.domain)}/disable-feature`, {}, { feature: feature })
  }

  function linkToDocs() {
    return (
      <a target="_blank" rel="noreferrer" href={docsLink} className="hover:underline text-indigo-700 dark:text-indigo-500" >
        Learn more...
      </a>
    )
  }

  function hideButton() {
    return (
      <div className="absolute right-0 top-0">
        <button
          onClick={requestHideSection}
          className="text-gray-500 dark:text-gray-400 hover:text-red-500 dark:hover:text-red-400 transition tracking-wide"
          tooltip={ `Hide ${sectionTitle}` }>
            <EyeSlashIcon className="inline-block w-5 h-5 mr-1" />
        </button>
      </div>
    )
  }

  return (
    <div className="relative md:mx-32 mt-6 mb-3 shadow-lg bg-gray-850 rounded-md" >
      <div className="px-8 py-3 font-small text-sm text-gray-300 dark:text-gray-200">
        {hideButton()}

        <div className="text-center mt-2 text-lg font-md text-gray-400">
          {title}
        </div>

        <div className="text-justify mt-4">
          {info} {linkToDocs()}
        </div>

        <div className="text-justify mt-8 text-xs italic text-gray-500">
          {hideNotice}
        </div>
      </div>
    </div>
  )
}