import React, { useState, useEffect, useCallback } from "react";

import * as api from '../../api'
import { addFilter } from '../../query'
import debounce from 'debounce-promise'
import { useMountedEffect } from '../../custom-hooks'
import { trimURL } from '../../util/url'
import { FilterLink } from "../reports/list";

const LIMIT = 100

export default function BreakdownModal(props) {
  const {site, query, reportInfo, getMetrics} = props
  const endpoint = `/api/stats/${encodeURIComponent(site.domain)}${reportInfo.endpoint}`
  const metrics = getMetrics(query)
  
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
    return addFilter(query, ['contains', reportInfo.dimension, [search]])
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
            <td
              key={metric.key}
              className="p-2 w-32 font-medium"
              align="right"
            >
              {metric.formatter(item[metric.key])}
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
                      <th
                        key={metric.label}
                        className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400"
                        align="right"
                      >
                        {metric.label}
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
