/** @format */

import React, { useState, useEffect, useCallback } from 'react'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import FlipMove from 'react-flip-move'

import FadeIn from '../../fade-in'
import MoreLink from '../more-link'
import Bar from '../bar'
import LazyLoader from '../../components/lazy-loader'
import classNames from 'classnames'
import { trimURL } from '../../util/url'
import {
  cleanLabels,
  replaceFilterByPrefix,
  isRealTimeDashboard,
  hasGoalFilter,
  plainFilterText
} from '../../util/filters'
import { useQueryContext } from '../../query-context'

const MAX_ITEMS = 9
export const MIN_HEIGHT = 380
const ROW_HEIGHT = 32
const ROW_GAP_HEIGHT = 4
const DATA_CONTAINER_HEIGHT =
  (ROW_HEIGHT + ROW_GAP_HEIGHT) * (MAX_ITEMS - 1) + ROW_HEIGHT
const COL_MIN_WIDTH = 70

export function FilterLink({
  path,
  filterInfo,
  onClick,
  children,
  extraClass
}) {
  const { query } = useQueryContext()
  const className = classNames(`${extraClass}`, {
    'hover:underline': !!filterInfo
  })

  if (filterInfo) {
    const { prefix, filter, labels } = filterInfo
    const newFilters = replaceFilterByPrefix(query, prefix, filter)
    const newLabels = cleanLabels(newFilters, query.labels, filter[1], labels)

    return (
      <AppNavigationLink
        title={`Add filter: ${plainFilterText({ ...query, labels: newLabels }, filter)}`}
        className={className}
        path={path}
        onClick={onClick}
        search={(search) => ({
          ...search,
          filters: newFilters,
          labels: newLabels
        })}
      >
        {children}
      </AppNavigationLink>
    )
  } else {
    return <span className={className}>{children}</span>
  }
}

function ExternalLink({ item, externalLinkDest }) {
  const dest = externalLinkDest && externalLinkDest(item)
  if (dest) {
    return (
      <a
        target="_blank"
        rel="noreferrer"
        href={dest}
        className="w-4 h-4 hidden group-hover:block"
      >
        <svg
          className="inline w-full h-full ml-1 -mt-1 text-gray-600 dark:text-gray-400"
          fill="currentColor"
          viewBox="0 0 20 20"
        >
          <path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path>
          <path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path>
        </svg>
      </a>
    )
  }

  return null
}

/**
 *
 * REQUIRED PROPS
 *
 * @param {Function} fetchData - A function that defines the data
 *    to be rendered, and should return a list of objects under a `results` key. Think of
 *    these objects as rows. The number of columns that are **actually rendered** is also
 *    configurable through the `metrics` prop, which also defines the keys under which
 *    column values are read, and how they're rendered.
 * @param {*} keyLabel - What each entry in the list represents (for UI only).
 * @param {Array.<Metric>} metrics - A list of `Metric` class objects, containing at least the `key,`
 *    `renderLabel`, and `renderValue` fields. Optionally, a Metric object can contain
 *    the keys `meta.plot` and `meta.hiddenOnMobile` to represent additional behavior
 *    for this metric in the ListReport.
 * @param {Function} getFilterFor - A function that takes a list item and returns [prefix, filter, labels]
 *    that should be applied when the list item is clicked. All existing filters matching prefix
 *    are removed. If a list item is not supposed to be clickable, this function should
 *    return `null` for that list item.
 *
 * OPTIONAL PROPS
 *
 * @param {Function} [onClick] - Function with additional action to be taken when a list entry is clicked.
 * @param {Object} [detailsLinkProps] - Navigation props to be passed to "More" link, if any.
 * @param {boolean} [maybeHideDetails] - Set this to `true` if the details button should be hidden on
 *     the condition that there are less than MAX_ITEMS entries in the list (i.e. nothing
 *     more to show).
 * @param {Function} [externalLinkDest] - A function that takes a list item and returns an external URL
 *     to navigate to. If this prop is given, an additional icon is rendered upon hovering
 *     the entry.
 * @param {Function} [renderIcon] - A function that takes a list item and returns the
 *     HTML of an icon (such as a flag, favicon, or a screen size icon) for a list item.
 * @param {string} [color] - Color of the comparison bars in light-mode.
 * @param {Function} [afterFetchData] - A function to be called directly after `fetchData`. Receives the
 *     raw API response as an argument. The return value is ignored by ListReport. Allows
 *     hooking into the request lifecycle and doing actions with returned metadata. For
 *     example, the parent component might want to control what happens when imported data
 *     is included or not.
 *
 * @returns {HTMLElement} Table of metrics, in the following format:
 * | keyLabel           | METRIC_1.renderLabel(query) | METRIC_2.renderLabel(query) | ...
 * |--------------------|-----------------------------|-----------------------------| ---
 * | LISTITEM_1.name    | LISTITEM_1[METRIC_1.key]    | LISTITEM_1[METRIC_2.key]    | ...
 * | LISTITEM_2.name    | LISTITEM_2[METRIC_1.key]    | LISTITEM_2[METRIC_2.key]    | ...
 */
export default function ListReport({
  keyLabel,
  metrics,
  colMinWidth = COL_MIN_WIDTH,
  afterFetchData,
  detailsLinkProps,
  maybeHideDetails,
  onClick,
  color,
  getFilterFor,
  renderIcon,
  externalLinkDest,
  fetchData
}) {
  const { query } = useQueryContext()
  const [state, setState] = useState({ loading: true, list: null, meta: null })
  const [visible, setVisible] = useState(false)

  const isRealtime = isRealTimeDashboard(query)
  const goalFilterApplied = hasGoalFilter(query)

  const getData = useCallback(() => {
    if (!isRealtime) {
      setState({ loading: true, list: null, meta: null })
    }
    fetchData().then((response) => {
      if (afterFetchData) {
        afterFetchData(response)
      }

      setState({ loading: false, list: response.results, meta: response.meta })
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [keyLabel, query])

  const onVisible = () => {
    setVisible(true)
  }

  useEffect(() => {
    if (isRealtime) {
      // When a goal filter is applied or removed, we always want the component to go into a
      // loading state, even in realtime mode, because the metrics list will change. We can
      // only read the new metrics once the new list is loaded.
      setState({ loading: true, list: null, meta: null })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [goalFilterApplied])

  useEffect(() => {
    if (visible) {
      if (isRealtime) {
        document.addEventListener('tick', getData)
      }
      getData()
    }

    return () => {
      document.removeEventListener('tick', getData)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [keyLabel, query, visible])

  // returns a filtered `metrics` list. Since currently, the backend can return different
  // metrics based on filters and existing data, this function validates that the metrics
  // we want to display are actually there in the API response.
  function getAvailableMetrics() {
    return metrics.filter((metric) => {
      return state.list.some((listItem) => listItem[metric.key] != null)
    })
  }

  function hiddenOnMobileClass(metric) {
    if (metric.meta.hiddenOnMobile) {
      return 'hidden md:block'
    } else {
      return ''
    }
  }

  function renderReport() {
    if (state.list && state.list.length > 0) {
      return (
        <div className="h-full flex flex-col">
          <div style={{ height: ROW_HEIGHT }}>{renderReportHeader()}</div>

          <div style={{ minHeight: DATA_CONTAINER_HEIGHT }}>
            {renderReportBody()}
          </div>

          {maybeRenderDetailsLink()}
        </div>
      )
    }
    return renderNoDataYet()
  }

  function renderReportHeader() {
    const metricLabels = getAvailableMetrics().map((metric) => {
      return (
        <div
          key={metric.key}
          className={`${metric.key} text-right ${hiddenOnMobileClass(metric)}`}
          style={{ minWidth: colMinWidth }}
        >
          {metric.renderLabel(query)}
        </div>
      )
    })

    return (
      <div className="pt-3 w-full text-xs font-bold tracking-wide text-gray-500 flex items-center dark:text-gray-400">
        <span className="flex-grow truncate">{keyLabel}</span>
        {metricLabels}
      </div>
    )
  }

  function renderReportBody() {
    return (
      <FlipMove className="flex-grow">
        {state.list.slice(0, MAX_ITEMS).map(renderRow)}
      </FlipMove>
    )
  }

  function renderRow(listItem) {
    return (
      <div key={listItem.name} style={{ minHeight: ROW_HEIGHT }}>
        <div className="flex w-full" style={{ marginTop: ROW_GAP_HEIGHT }}>
          {renderBarFor(listItem)}
          {renderMetricValuesFor(listItem)}
        </div>
      </div>
    )
  }

  function renderBarFor(listItem) {
    const lightBackground = color || 'bg-green-50'
    const metricToPlot = metrics.find((metric) => metric.meta.plot).key

    return (
      <div className="flex-grow w-full overflow-hidden">
        <Bar
          count={listItem[metricToPlot]}
          all={state.list}
          bg={`${lightBackground} dark:bg-gray-500 dark:bg-opacity-15`}
          plot={metricToPlot}
        >
          <div className="flex justify-start px-2 py-1.5 group text-sm dark:text-gray-300 relative z-9 break-all w-full">
            <FilterLink
              filterInfo={getFilterFor(listItem)}
              onClick={onClick}
              extraClass="max-w-max w-full flex items-center md:overflow-hidden"
            >
              {maybeRenderIconFor(listItem)}

              <span className="w-full md:truncate">
                {trimURL(listItem.name, colMinWidth)}
              </span>
            </FilterLink>
            <ExternalLink item={listItem} externalLinkDest={externalLinkDest} />
          </div>
        </Bar>
      </div>
    )
  }

  function maybeRenderIconFor(listItem) {
    if (renderIcon) {
      return renderIcon(listItem)
    }
  }

  function renderMetricValuesFor(listItem) {
    return getAvailableMetrics().map((metric) => {
      return (
        <div
          key={`${listItem.name}__${metric.key}`}
          className={`text-right ${hiddenOnMobileClass(metric)}`}
          style={{ width: colMinWidth, minWidth: colMinWidth }}
        >
          <span className="font-medium text-sm dark:text-gray-200 text-right">
            {metric.renderValue(listItem, state.meta)}
          </span>
        </div>
      )
    })
  }

  function renderLoading() {
    return (
      <div
        className="w-full flex flex-col justify-center"
        style={{ minHeight: `${MIN_HEIGHT}px` }}
      >
        <div className="mx-auto loading">
          <div></div>
        </div>
      </div>
    )
  }

  function renderNoDataYet() {
    return (
      <div
        className="w-full h-full flex flex-col justify-center"
        style={{ minHeight: `${MIN_HEIGHT}px` }}
      >
        <div className="mx-auto font-medium text-gray-500 dark:text-gray-400">
          No data yet
        </div>
      </div>
    )
  }

  function maybeRenderDetailsLink() {
    const moreResultsAvailable = state.list.length >= MAX_ITEMS
    const hideDetails = maybeHideDetails && !moreResultsAvailable

    const showDetails = !!detailsLinkProps && !state.loading && !hideDetails
    return (
      showDetails && (
        <MoreLink
          className={'mt-2'}
          linkProps={detailsLinkProps}
          list={state.list}
        />
      )
    )
  }

  return (
    <LazyLoader onVisible={onVisible}>
      <div className="w-full" style={{ minHeight: `${MIN_HEIGHT}px` }}>
        {state.loading && renderLoading()}
        {!state.loading && (
          <FadeIn show={!state.loading} className="h-full">
            {renderReport()}
          </FadeIn>
        )}
      </div>
    </LazyLoader>
  )
}
