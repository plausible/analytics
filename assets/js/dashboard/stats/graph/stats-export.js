import React, { useState } from "react";
import * as api from '../../api';
import { getCurrentInterval } from "./interval-picker";
import { useSiteContext } from "../../site-context";
import { useQueryContext } from "../../query-context";
import { useUserContext } from '../../user-context';

export default function StatsExport() {
  const site = useSiteContext();
  const { query } = useQueryContext();
  const [exporting, setExporting] = useState(false)
  const user = useUserContext();

  if (!user.loggedIn) {
    return null;
  }

  function startExport() {
    setExporting(true)
    document.cookie = "exporting="
    pollExportReady()
  }

  function pollExportReady() {
    if (document.cookie.includes('exporting')) {
      setTimeout(pollExportReady, 1000)
    } else {
      setExporting(false)
    }
  }

  function renderLoading() {
    return (
      <svg className="animate-spin h-4 w-4 text-indigo-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    )
  }

  function renderExportLink() {
    const interval = getCurrentInterval(site, query)
    const queryParams = api.serializeQuery(query, [{ interval, comparison: undefined }])
    const endpoint = `/${encodeURIComponent(site.domain)}/export${queryParams}`

    return (
      <a href={endpoint} download onClick={startExport}>
        <svg className="absolute text-gray-700 feather dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-600" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
          <polyline points="7 10 12 15 17 10"></polyline>
          <line x1="12" y1="15" x2="12" y2="3"></line>
        </svg>
      </a>
    )
  }

  return (
    <div className="w-4 h-4 mx-2">
      {exporting && renderLoading()}
      {!exporting && renderExportLink()}
    </div>
  )
}
