/** @format */

import React, {
  useState,
  useEffect,
  useCallback,
  ReactNode,
  useMemo
} from 'react'
import { AppNavigationLinkProps } from '../../navigation/use-app-navigate'
import FlipMove from 'react-flip-move'

import FadeIn from '../../fade-in'
import MoreLink from '../more-link'
import Bar from '../bar'
import LazyLoader from '../../components/lazy-loader'
import { trimURL } from '../../util/url'
import {
  isRealTimeDashboard,
  hasConversionGoalFilter
} from '../../util/filters'
import { useQueryContext } from '../../query-context'
import { Metric } from './metrics'
import { DrilldownLink, FilterInfo } from '../../components/drilldown-link'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { BreakdownResultMeta } from '../../query'

const MAX_ITEMS = 9
export const MIN_HEIGHT = 380
const ROW_HEIGHT = 32
const ROW_GAP_HEIGHT = 4
const DATA_CONTAINER_HEIGHT =
  (ROW_HEIGHT + ROW_GAP_HEIGHT) * (MAX_ITEMS - 1) + ROW_HEIGHT
const COL_MIN_WIDTH = 70

function ExternalLink<T>({
  item,
  getExternalLinkUrl
}: {
  item: T
  getExternalLinkUrl?: (item: T) => string
}) {
  const dest = getExternalLinkUrl && getExternalLinkUrl(item)
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

export interface SharedReportProps<
  TListItem extends Record<string, unknown> = Record<string, unknown>,
  TResponse = { results: TListItem[]; meta: BreakdownResultMeta }
> {
  getMetrics: (options: {
    site: PlausibleSite
    situation: { is_filtering_on_goal: boolean; is_realtime_period: boolean }
  }) => Metric[]
  /** A function that takes a list item and returns the
   *    that should be applied when the list item is clicked. All existing filters matching prefix
   *    are removed. If a list item is not supposed to be clickable, this function should
   *    return `null` for that list item. */
  getFilterInfo: (item: TListItem) => FilterInfo
  /** A function that takes a list item and returns the HTML of an icon */
  renderIcon?: (item: TListItem) => ReactNode
  /** A function that takes a list item and returns an external URL
   *     to navigate to. If this prop is given, an additional icon is rendered upon hovering
   *     the entry. */
  getExternalLinkUrl?: (item: TListItem) => string
  /** A function that defines the data
   *    to be rendered, and should return a list of objects under a `results` key. Think of
   *    these objects as rows. The number of columns that are **actually rendered** is also
   *    configurable through the `metrics` prop, which also defines the keys under which
   *    column values are read, and how they're rendered. */
  fetchData: () => Promise<TResponse>
  /** A function to be called directly after `fetchData`. Receives the
   *     raw API response as an argument. The return value is ignored by ListReport. Allows
   *     hooking into the request lifecycle and doing actions with returned metadata. For
   *     example, the parent component might want to control what happens when imported data
   *     is included or not. */
  afterFetchData?: (response: TResponse) => void
  afterFetchNextPage?: (response: { results: TListItem[] }) => void
}

type ListReportProps = {
  /** What each entry in the list represents (for UI only). */
  keyLabel: string
  metrics: Metric[]
  colMinWidth?: number
  /** A function to be called directly after `fetchData`. Receives the
   *     raw API response as an argument. The return value is ignored by ListReport. Allows
   *     hooking into the request lifecycle and doing actions with returned metadata. For
   *     example, the parent component might want to control what happens when imported data
   *     is included or not. */
  detailsLinkProps?: AppNavigationLinkProps
  /** Set this to `true` if the details button should be hidden on
   *     the condition that there are less than MAX_ITEMS entries in the list (i.e. nothing
   *     more to show).
   */
  maybeHideDetails?: boolean
  /** Function with additional action to be taken when a list entry is clicked. */
  onClick?: () => void
  /** Color of the comparison bars in light-mode. */
  color?: string
  /** A function that takes a list item and returns [prefix, filter, labels]
   *    that should be applied when the list item is clicked. All existing filters matching prefix
   *    are removed. If a list item is not supposed to be clickable, this function should
   *    return `null` for that list item. */
}

/**
 * @returns {HTMLElement} Table of metrics, in the following format:
 * | keyLabel           | METRIC_1.renderLabel(query) | METRIC_2.renderLabel(query) | ...
 * |--------------------|-----------------------------|-----------------------------| ---
 * | LISTITEM_1.name    | LISTITEM_1[METRIC_1.key]    | LISTITEM_1[METRIC_2.key]    | ...
 * | LISTITEM_2.name    | LISTITEM_2[METRIC_1.key]    | LISTITEM_2[METRIC_2.key]    | ...
 */
export default function ListReport<
  TListItem extends Record<string, unknown> & { name: string }
>({
  keyLabel,
  getMetrics,
  colMinWidth = COL_MIN_WIDTH,
  afterFetchData,
  detailsLinkProps,
  maybeHideDetails,
  onClick,
  color,
  getFilterInfo,
  renderIcon,
  getExternalLinkUrl,
  fetchData
}: ListReportProps & SharedReportProps<TListItem>) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const [state, setState] = useState<{
    loading: boolean
    list: TListItem[] | null
    meta: BreakdownResultMeta | null
  }>({ loading: true, list: null, meta: null })
  const [visible, setVisible] = useState(false)

  const isRealtime = isRealTimeDashboard(query)
  const goalFilterApplied = hasConversionGoalFilter(query)

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

  const metrics = useMemo(
    () =>
      !state.meta ? [] : getMetrics({ site, situation: state.meta.situation }),
    [site, getMetrics, state.meta]
  )
  // returns a filtered `metrics` list. Since currently, the backend can return different
  // metrics based on filters and existing data, this function validates that the metrics
  // we want to display are actually there in the API response.
  function getAvailableMetrics() {
    return metrics.filter((metric) =>
      state.list
        ? state.list.some((listItem) => listItem[metric.key] != null)
        : false
    )
  }

  function hiddenOnMobileClass(metric: Metric) {
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
            <FlipMove className="flex-grow">
              {state.list.slice(0, MAX_ITEMS).map(renderRow)}
            </FlipMove>
          </div>

          {!!detailsLinkProps &&
            !state.loading &&
            !(maybeHideDetails && !(state.list.length >= MAX_ITEMS)) && (
              <MoreLink
                onClick={undefined}
                className={'mt-2'}
                linkProps={detailsLinkProps}
                list={state.list}
              />
            )}
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

  function renderRow(listItem: TListItem) {
    return (
      <div key={listItem.name} style={{ minHeight: ROW_HEIGHT }}>
        <div className="flex w-full" style={{ marginTop: ROW_GAP_HEIGHT }}>
          {renderBarFor(listItem)}
          {renderMetricValuesFor(listItem)}
        </div>
      </div>
    )
  }

  function renderBarFor(listItem: TListItem) {
    const lightBackground = color || 'bg-green-50'
    const metricToPlot = metrics.find((metric) => metric.meta.plot)?.key

    return (
      <div className="flex-grow w-full overflow-hidden">
        <Bar
          maxWidthDeduction={undefined}
          count={listItem[metricToPlot]}
          all={state.list}
          bg={`${lightBackground} dark:bg-gray-500 dark:bg-opacity-15`}
          plot={metricToPlot}
        >
          <div className="flex justify-start px-2 py-1.5 group text-sm dark:text-gray-300 relative z-9 break-all w-full">
            <DrilldownLink
              filterInfo={getFilterInfo(listItem)}
              onClick={onClick}
              extraClass="max-w-max w-full flex items-center md:overflow-hidden"
            >
              {maybeRenderIconFor(listItem)}

              <span className="w-full md:truncate">
                {trimURL(listItem.name, colMinWidth)}
              </span>
            </DrilldownLink>
            <ExternalLink
              item={listItem}
              getExternalLinkUrl={getExternalLinkUrl}
            />
          </div>
        </Bar>
      </div>
    )
  }

  function maybeRenderIconFor(listItem: TListItem) {
    if (renderIcon) {
      return renderIcon(listItem)
    }
  }

  function renderMetricValuesFor(listItem: TListItem) {
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
