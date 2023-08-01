import React, { useEffect, useState } from "react";
import { Link } from 'react-router-dom'
import { withRouter } from 'react-router-dom'
import Money from "../behaviours/money";

import Modal from './modal'
import * as api from '../../api'
import * as url from "../../util/url";
import numberFormatter from '../../util/number-formatter'
import {parseQuery} from '../../query'

function ConversionsModal(props) {
  const site = props.site
  const query = parseQuery(props.location.search, site)

  const [loading, setLoading] = useState(true)
  const [moreResultsAvailable, setMoreResultsAvailable] = useState(false)
  const [page, setPage] = useState(1)
  const [list, setList] = useState([])

  useEffect(() => {
    fetchData()
  }, [])

  function fetchData() {
    api.get(url.apiPath(site, `/conversions`), query, {limit: 100, page})
      .then((res) => {
        setLoading(false)
        setList(list.concat(res))
        setPage(page + 1)
        setMoreResultsAvailable(res.length >= 100)
      })
  }

  function loadMore() {
    setLoading(true)
    fetchData()
  }

  function renderLoadMore() {
    return (
      <div className="w-full text-center my-4">
        <button onClick={loadMore} type="button" className="button">
          Load more
        </button>
      </div>
    )
  }

  function filterSearchLink(listItem) {
    const searchParams = new URLSearchParams(window.location.search)
    searchParams.set('goal', listItem.name)
    return searchParams.toString()
  }

  function renderListItem(listItem, hasRevenue) {
    return (
      <tr className="text-sm dark:text-gray-200" key={listItem.name}>
        <td className="p-2">
          <Link
            to={{pathname: url.siteBasePath(site), search: filterSearchLink(listItem)}}
            className="hover:underline block truncate">
              {listItem.name}
          </Link>
        </td>
        <td className="p-2 w-24 font-medium" align="right">{numberFormatter(listItem.visitors)}</td>
        <td className="p-2 w-24 font-medium" align="right">{numberFormatter(listItem.events)}</td>
        <td className="p-2 w-24 font-medium" align="right">{listItem.conversion_rate}%</td>
        { hasRevenue && <td className="p-2 w-24 font-medium" align="right"><Money formatted={listItem.total_revenue}/></td> }
        { hasRevenue && <td className="p-2 w-24 font-medium" align="right"><Money formatted={listItem.average_revenue}/></td> }
      </tr>
    )
  }

  function renderLoading() {
    return <div className="loading my-16 mx-auto"><div></div></div>
  }

  function renderBody() {
    const hasRevenue = list.some((goal) => goal.total_revenue)

    return (
      <>
        <h1 className="text-xl font-bold dark:text-gray-100">Goal Conversions</h1>

        <div className="my-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <table className="w-max overflow-x-auto md:w-full table-striped table-fixed">
            <thead>
              <tr>
                <th className="p-2 w-48 md:w-56 lg:w-1/3 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400 truncate" align="left">Goal</th>
                <th className="p-2 w-24 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Uniques</th>
                <th className="p-2 w-24 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Total</th>
                <th className="p-2 w-24 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">CR</th>
                {hasRevenue && <th className="p-2 w-24 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Revenue</th>}
                {hasRevenue && <th className="p-2 w-24 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Average</th>}
              </tr>
            </thead>
            <tbody>
              { list.map((item) => renderListItem(item, hasRevenue)) }
            </tbody>
          </table>
        </main>
      </>
    )
  }

  return (
    <Modal site={site}>
      { renderBody() }
      { loading && renderLoading() }
      { !loading && moreResultsAvailable && renderLoadMore() }
    </Modal>
  )
}

export default withRouter(ConversionsModal)
