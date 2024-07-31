import React, { useEffect, useState } from 'react';

import * as storage from '../../util/storage'
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning';
import Properties from '../behaviours/props';

const labelFor = {
  'phx-event': 'LiveView Sessions',
  'phx-push': 'Server Events',
  'js-submit': 'Form Submits'
}

export default function LiveView(props) {
  const { site, query } = props
  const tabKey = `liveviewTab__${site.domain}`
  const storedTab = storage.getItem(tabKey)
  const [mode, setMode] = useState(storedTab || 'live-view')
  const [loading, setLoading] = useState(true)
  const [skipImportedReason, setSkipImportedReason] = useState(null)

  function switchTab(mode) {
    storage.setItem(tabKey, mode)
    setMode(mode)
  }

  function afterFetchData(apiResponse) {
    setLoading(false)
    setSkipImportedReason(apiResponse.skip_imported_reason)
  }

  useEffect(() => setLoading(true), [query, mode])

  function renderPill(name, pill) {
    const isActive = mode === pill

    if (isActive) {
      return (
        <button
          className="inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading"
          key={pill}
        >
          {name}
        </button>
      )
    }

    return (
      <button
        className="hover:text-indigo-600 cursor-pointer"
        onClick={() => switchTab(pill)}
        key={pill}
      >
        {name}
      </button>
    )
  }

  function addGoal(query, goal) {
    return {
      ...query,
      filters: [['is', 'goal', [goal]]]
    }
  }

  return (
    <div className="w-full p-4 bg-white dark:bg-gray-825 rounded shadow-xl mt-6">
      {/* Header Container */}
      <div className="w-full flex justify-between">
        <div className="flex gap-x-1">
          <h3 className="font-bold dark:text-gray-100">
            {labelFor[mode] || 'LiveView Events'}
          </h3>
          <ImportedQueryUnsupportedWarning loading={loading} query={query} skipImportedReason={skipImportedReason} />
        </div>
        <div className="flex font-medium text-xs text-gray-500 dark:text-gray-400 space-x-2">
          {Object.entries(labelFor).map(([key, label]) => renderPill(label, key))}
        </div>
      </div>
      {/* Main Contents */}
      <Properties site={site} query={addGoal(query, mode)} afterFetchData={afterFetchData} />
    </div>
  )
}
