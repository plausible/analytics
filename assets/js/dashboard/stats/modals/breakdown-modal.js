import React, { useState, useEffect, useCallback } from "react";

import * as api from '../../api'
import debounce from 'debounce-promise'
import { useMountedEffect } from '../../custom-hooks'
import { trimURL } from '../../util/url'
import { FilterLink } from "../reports/list";

const LIMIT = 100

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

//   * `site` - the current dashboard site

//   * `query` - a read-only query object representing the query state of the
//     dashboard (e.g. `filters`, `period`, `with_imported`, etc)

//   * `title` - title of the report to render on the top left.

//   * `endpoint` - the last part of the endpoint (e.g. "/sources") to query. this
//     value will be appended to `/${props.site.domain}`

//   * `metrics` - a list of `Metric` class objects which represent the columns
//     rendered in the report

//   * `getFilterInfo` - a function that takes a `listItem` and returns a map with
//     the necessary information to be able to link to a dashboard where that item
//     is filtered by. If a list item is not supposed to be a filter link, this
//     function should return `null` for that item.

//   * `addSearchFilter` - a function that takes a query and the search string as
//     arguments, and returns a new query with an additional search filter.
export default function BreakdownModal(props) {
  const {site, query, reportInfo, metrics} = props
  const endpoint = `/api/stats/${encodeURIComponent(site.domain)}${reportInfo.endpoint}`
  
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [results, setResults] = useState([])
  const [page, setPage] = useState(1)
  const [moreResultsAvailable, setMoreResultsAvailable] = useState(false)

  const fetchData = useCallback(debounce(() => {
    api.get(endpoint, withSearch(query), { limit: LIMIT, page: 1 })
      .then((response) => {
        setLoading(false)
        setPage(1)
        setResults(response.results)
        setMoreResultsAvailable(response.results.length === LIMIT)
      })
  }, 200), [search])
  
  useEffect(() => { fetchData() }, [search])
  useMountedEffect(() => { fetchNextPage() }, [page])

  function fetchNextPage() {
    if (page > 1) {
      api.get(endpoint, withSearch(query), { limit: LIMIT, page })
        .then((response) => {
          setLoading(false)
          setResults(results.concat(response.results))
          setMoreResultsAvailable(response.results.length === LIMIT)
        })
    }
  }

  function withSearch(query) {
    if (search === '') { return query}
    return props.addSearchFilter(query, search)
  }

  function loadNextPage() {
    setLoading(true)
    setPage(page + 1)
  }

  function renderRow(item) {
    return (
      <tr className="text-sm dark:text-gray-200" key={item.name}>
        <td className="p-2 truncate">
          <FilterLink
            pathname={`/${encodeURIComponent(site.domain)}`}
            query={query}
            filterInfo={props.getFilterInfo(item)}
          >
            {trimURL(item.name, 40)}
          </FilterLink>
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

  function renderLoading() {
    if (loading) {
      return <div className="loading my-16 mx-auto"><div></div></div>
    } else if (moreResultsAvailable) {
      return (
        <div className="w-full text-center my-4">
          <button onClick={loadNextPage} type="button" className="button">
            Load more
          </button>
        </div>
      )
    }
  }

  function renderBody() {
    if (results) {
      return (
        <>
          <div className="flex justify-between items-center">
            <h1 className="text-xl font-bold dark:text-gray-100">{ reportInfo.title }</h1>
            <input
              type="text"
              placeholder="Search"
              className="shadow-sm dark:bg-gray-900 dark:text-gray-100 focus:ring-indigo-500 focus:border-indigo-500 block sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800"
              onChange={(e) => { setSearch(e.target.value) }}
            />
          </div>

          <div className="my-4 border-b border-gray-300"></div>
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
                { results.map(renderRow) }
              </tbody>
            </table>
          </main>
        </>
      )
    }
  }

  return (
    <div className="w-full h-full">
      { renderBody() }
      { renderLoading() }
    </div>
  )
}
