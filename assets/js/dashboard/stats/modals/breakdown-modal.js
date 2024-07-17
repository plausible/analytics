import React, { useState, useEffect, useRef } from "react";

import * as api from '../../api'
import { trimURL } from '../../util/url'
import { FilterLink } from "../reports/list";
import { useQueryContext } from "../../query-context";
import { useSiteContext } from "../../site-context";
import { useInfiniteQuery, useQueryClient } from "@tanstack/react-query"
import { useDebounce } from "../../custom-hooks";

const LIMIT = 100
const MIN_HEIGHT_PX = 500

// The main function component for rendering the "Details" reports on the dashboard,
// i.e. a breakdown by a single (non-time) dimension, with a given set of metrics.

// BreakdownModal is expected to be rendered inside a `<Modal>`, which has it's own
// specific URL pathname (e.g. /plausible.io/sources). During the lifecycle of a
// BreakdownModal, the `query` object is not expected to change.

// ### Search As You Type

// Debounces API requests when a search input changes and applies a `contains` filter
// on the given breakdown dimension (see the required `addSearchFilter` prop)

// ### Filter Links

// Dimension values can act as links back to the dashboard, where that specific value
// will be filtered by. (see the `getFilterInfo` required prop)

// ### Pagination

// By default, the component fetches `LIMIT` results. When exactly this number of
// results is received, a "Load More" button is rendered for fetching the next page
// of results.

// ### Required Props

//   * `reportInfo` - a map with the following required keys:

//        * `title` - the title of the report to render on the top left

//        * `endpoint` - the last part of the endpoint (e.g. "/sources") to query

//        * `dimensionLabel` - a string to render as the dimension column header.

//   * `metrics` - a list of `Metric` class objects which represent the columns
//     rendered in the report

//   * `getFilterInfo` - a function that takes a `listItem` and returns a map with
//     the necessary information to be able to link to a dashboard where that item
//     is filtered by. If a list item is not supposed to be a filter link, this
//     function should return `null` for that item.

// ### Optional Props 

//   * `renderIcon` - a function that renders an icon for the given list item.

//   * `getExternalLinkURL` - a function that takes a list litem, and returns a
//     valid link href for this item. If the item is not supposed to be a link,
//     the function should return `null` for that item. Otherwise, if the returned
//     value exists, a small pop-out icon will be rendered whenever the list item
//     is hovered. When the icon is clicked, opens the external link in a new tab.

//   * `searchEnabled` - a boolean that determines if the search feature is enabled.
//     When true, the `addSearchFilter` function is expected. Is true by default.

//   * `addSearchFilter` - a function that takes a query object and a search string
//     as arguments, and returns a new `query` with an additional search filter.

//   * `afterFetchData` - a callback function taking an API response as an argument.
//     If this function is passed via props, it will be called after a successful
//     API response from the `fetchData` function.

//   * `afterFetchNextPage` - a function with the same behaviour as `afterFetchData`,
//     but will be called after a successful next page load in `fetchNextPage`.
export default function BreakdownModal({
  reportInfo,
  metrics,
  renderIcon,
  getExternalLinkURL,
  searchEnabled = true,
  afterFetchData,
  afterFetchNextPage,
  addSearchFilter,
  getFilterInfo
}) {
  const searchBoxRef = useRef(null)
  const { query } = useQueryContext();
  const site = useSiteContext();

  const endpoint = `/api/stats/${encodeURIComponent(site.domain)}${reportInfo.endpoint}`
  const [search, setSearch] = useState('')

  const queryFn = async ({ pageParam, queryKey }) => {
    const {search, query} = queryKey[1]

    let queryWithSearchFilter = {...query}

    if (searchEnabled && search !== '') {
      queryWithSearchFilter = addSearchFilter(query, search)
    }

    const response = await api.get(endpoint, queryWithSearchFilter, { limit: LIMIT, page: pageParam, detailed: true });
    
    if (pageParam === 1 && typeof afterFetchData === 'function') {
      afterFetchData(response)
    }

    if (pageParam > 1 && typeof afterFetchNextPage === 'function') {
      afterFetchNextPage(response)
    }

    return response.results
  }

  const {data, hasNextPage, fetchNextPage, isFetching, isPending } = useInfiniteQuery({
    queryKey: [reportInfo.endpoint, {search, query}],
    getNextPageParam: (lastPageResults, _, lastPageIndex) => lastPageResults.length === LIMIT ? lastPageIndex + 1 : null,
    initialPageParam: 1,
    queryFn,
  })

  const queryClient = useQueryClient()

  useEffect(() => {
    const key = [reportInfo.endpoint]
    return () => {
      queryClient.setQueriesData(key, (data) => {
        if (data?.pages?.length) {
          return {
            pages: data.pages.slice(0, 1),
            pageParams: data.pageParams.slice(0, 1),
          }  
        }
      })  
    }
  }, [queryClient, reportInfo.endpoint])

  useEffect(() => {
    if (!searchEnabled) { return }

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
  }, [searchEnabled])

  function maybeRenderIcon(item) {
    if (typeof renderIcon === 'function') {
      return renderIcon(item)
    }
  }

  function maybeRenderExternalLink(item) {
    if (typeof getExternalLinkURL === 'function') {
      const linkUrl = getExternalLinkURL(item)

      if (!linkUrl) { return null }

      return (
        <a target="_blank" href={linkUrl} rel="noreferrer" className="hidden group-hover:block">
          <svg className="inline h-4 w-4 ml-1 -mt-1 text-gray-600 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
        </a>
      )
    }
  }

  function renderRow(item) {
    return (
      <tr className="text-sm dark:text-gray-200" key={item.name}>
        <td className="p-2 truncate flex items-center group">
          {maybeRenderIcon(item)}
          <FilterLink
            pathname={`/${encodeURIComponent(site.domain)}`}
            filterInfo={getFilterInfo(item)}
          >
            {trimURL(item.name, 40)}
          </FilterLink>
          {maybeRenderExternalLink(item)}
        </td>
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
    return (
      <div className="w-full text-center my-4">
        <button onClick={fetchNextPage} type="button" className="button">
          Load more
        </button>
      </div>
    )
  }

  function handleInputChange(e) {
    setSearch(e.target.value)
  }

  const debouncedHandleInputChange = useDebounce(handleInputChange)

  function renderSearchInput() {
    return (
      <input
        ref={searchBoxRef}
        type="text"
        placeholder="Search"
        className="shadow-sm dark:bg-gray-900 dark:text-gray-100 focus:ring-indigo-500 focus:border-indigo-500 block sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800 w-48"
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
                  {reportInfo.dimensionLabel}
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

  return (
    <div className="w-full h-full">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-x-2">
          <h1 className="text-xl font-bold dark:text-gray-100">{reportInfo.title}</h1>
          {!isPending && isFetching && renderSmallLoadingSpinner()}
        </div>
        {searchEnabled && renderSearchInput()}
      </div>
      <div className="my-4 border-b border-gray-300"></div>
      <div style={{ minHeight: `${MIN_HEIGHT_PX}px` }}>
        {isPending && renderInitialLoadingSpinner()}
        {!isPending && renderModalBody()}
        {!isFetching && hasNextPage && renderLoadMoreButton()}
      </div>
    </div>
  )
}
