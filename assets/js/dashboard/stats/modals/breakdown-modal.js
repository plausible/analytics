import React, { useState, useEffect } from "react";
import { Link } from 'react-router-dom'

import * as api from '../../api'
import { trimURL, updatedQuery } from '../../util/url'
import { replaceFilterByPrefix } from "../../util/filters";

const LIMIT = 100

export default function BreakdownModal(props) {
  const {site, query, reportInfo, getMetrics} = props
  const endpoint = `/api/stats/${encodeURIComponent(site.domain)}${reportInfo.endpoint}`
  const metrics = getMetrics(query)
  
  const [loading, setLoading] = useState(true)
  const [results, setResults] = useState([])
  const [page, setPage] = useState(1)
  const [moreResultsAvailable, setMoreResultsAvailable] = useState(false)

  useEffect(fetchData, [page])

  function fetchData() {
    api.get(endpoint, query, { limit: LIMIT, page })
      .then((response) => {
        setLoading(false)
        setResults(results.concat(response.results))
        setMoreResultsAvailable(response.results.length === LIMIT)
      })
  }

  function loadNextPage() {
    setLoading(true)
    setPage(page + 1)
  }

  function renderRow(item) {
    const filters = replaceFilterByPrefix(query, reportInfo.dimension, ["is", reportInfo.dimension, [item.name]])

    return (
      <tr className="text-sm dark:text-gray-200" key={item.name}>
        <td className="p-2 truncate">
          <Link
            to={{
              pathname: `/${encodeURIComponent(site.domain)}`,
              search: updatedQuery({ filters })
            }}
            className="hover:underline"
          >
            {trimURL(item.name, 40)}
          </Link>
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
          <h1 className="text-xl font-bold dark:text-gray-100">{ reportInfo.title }</h1>

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
