import React, { useState, useEffect, useRef } from "react";

import Modal from './modal'
import RocketIcon from './rocket-icon'
import { useQueryContext } from "../../query-context";
import { useSiteContext } from "../../site-context";
import { useAPIClient } from "../../hooks/api-client";
import { useDebounce } from "../../custom-hooks";
import { createVisitors, Metric, renderNumberWithTooltip } from "../reports/metrics";
import numberFormatter, { percentageFormatter } from "../../util/number-formatter";
import classNames from "classnames";
import { MIN_HEIGHT_PX } from "./breakdown-modal";

function GoogleKeywordsModal() {
  const searchBoxRef = useRef(null)
  const { query } = useQueryContext()
  const site = useSiteContext()
  const endpoint = `/api/stats/${encodeURIComponent(site.domain)}/referrers/Google`

  const [search, setSearch] = useState('')  

  const metrics = [
    createVisitors({renderLabel: (_query) => 'Visitors'}),
    new Metric({width: 'w-28', key: 'impressions', renderLabel: (_query) => 'Impressions', renderValue: renderNumberWithTooltip, sortable: false}),
    new Metric({width: 'w-16', key: 'ctr', renderLabel: (_query) => 'CTR', renderValue: percentageFormatter, sortable: false}),
    new Metric({width: 'w-28', key: 'position', renderLabel: (_query) => 'Position', renderValue: numberFormatter, sortable: false})
  ]

  const {
    data,
    hasNextPage,
    fetchNextPage,
    isFetchingNextPage,
    isFetching,
    isPending,
    error,
    status
  } = useAPIClient({
    key: [endpoint, {query, search}],
    getRequestParams: (key) => {
      const [_endpoint, {query, search}] = key
      const params = { detailed: true }

      return [query, search === '' ? params : {...params, search}]
    },
    initialPageParam: 0
  })

  useEffect(() => {
    const searchBox = searchBoxRef.current

    const handleKeyUp = (event) => {
      if (event.key === 'Escape') {
        event.target.blur()
        event.stopPropagation()
      }
    }

    searchBox.addEventListener('keyup', handleKeyUp);

    return () => {
      searchBox.removeEventListener('keyup', handleKeyUp);
    }
  }, [])

  function renderRow(item) {
    return (
      <tr className="text-sm dark:text-gray-200" key={item.name}>
        <td className="p-2">{item.name}</td>
        {metrics.map((metric) => {
          return (
            <td key={metric.key} className="p-2 w-32 font-medium" align="right">
              {metric.renderValue(item[metric.key])}
            </td>
          )
        })}
      </tr>
    )
  }

  function renderInitialLoadingSpinner() {
    return (
      <div className="w-full h-full flex flex-col justify-center" style={{ minHeight: `${MIN_HEIGHT_PX}px` }}>
        <div className="mx-auto loading"><div></div></div>
      </div>
    )
  }

  function renderSmallLoadingSpinner() {
    return (
      <div className="loading sm"><div></div></div>
    )
  }

  function renderLoadMoreButton() {
    if (isPending) return null
    if (!isFetching && !hasNextPage) return null

    return (
      <div className="flex flex-col w-full my-4 items-center justify-center h-10">
        {!isFetching && <button onClick={fetchNextPage} type="button" className="button">Load more</button>}
        {isFetchingNextPage && renderSmallLoadingSpinner()}
      </div>
    )
  }

  function handleInputChange(e) {
    setSearch(e.target.value)
  }

  const debouncedHandleInputChange = useDebounce(handleInputChange)

  function renderSearchInput() {
    const searchBoxClass = classNames('shadow-sm dark:bg-gray-900 dark:text-gray-100 focus:ring-indigo-500 focus:border-indigo-500 block sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800 w-48', {
      'pointer-events-none' : status === 'error'
    })
    return (
      <input
        ref={searchBoxRef}
        type="text"
        placeholder={"Search"}
        className={searchBoxClass}
        onChange={debouncedHandleInputChange}
      />
    )
  }

  function renderModalBody() {
    if (data?.pages?.length) {
      return (
        <main className="modal__content">
          <table className="w-max overflow-x-auto md:w-full table-striped table-fixed">
            <thead>
              <tr>
                <th
                  className="p-2 w-48 md:w-56 lg:w-1/3 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400"
                  align="left"
                >
                  Search term
                </th>
                {metrics.map((metric) => {
                  return (
                    <th key={metric.key} className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">
                      {metric.renderLabel(query)}
                    </th>
                  )
                })}
              </tr>
            </thead>
            <tbody>
              {data.pages.map((p) => p.map(renderRow))}
            </tbody>
          </table>
        </main>
      )
    }
  }

  function renderError() {
    return (
      <div
        className="grid grid-rows-2 text-gray-700 dark:text-gray-300"
        style={{ height: `${MIN_HEIGHT_PX}px` }}
      >
        <div className="text-center self-end"><RocketIcon /></div>
        <div className="text-lg text-center">{error.message}</div>
      </div>
    )
  }

  return (
    <Modal >
      <div className="w-full h-full">
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-x-2">
            <h1 className="text-xl font-bold dark:text-gray-100">Google Search Terms</h1>
            {!isPending && isFetching && renderSmallLoadingSpinner()}
          </div>
          {renderSearchInput()}
        </div>
        <div className="my-4 border-b border-gray-300"></div>
        <div style={{ minHeight: `${MIN_HEIGHT_PX}px` }}>
          {status === 'error' && renderError()}
          {isPending && renderInitialLoadingSpinner()}
          {!isPending && renderModalBody()}
          {renderLoadMoreButton()}
        </div>
      </div>
    </Modal>
  )
}

export default GoogleKeywordsModal
