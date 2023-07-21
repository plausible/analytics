import React, { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom'
import FlipMove from 'react-flip-move';

import { displayMetricValue, metricLabelFor } from './metrics';
import FadeIn from '../../fade-in'
import MoreLink from '../more-link'
import Bar from '../bar'
import LazyLoader from '../../components/lazy-loader'
import classNames from 'classnames'

const MAX_ITEMS = 9
const MIN_HEIGHT = 380
const ROW_HEIGHT = 32
const ROW_GAP_HEIGHT = 4
const DATA_CONTAINER_HEIGHT = (ROW_HEIGHT + ROW_GAP_HEIGHT) * (MAX_ITEMS - 1) + ROW_HEIGHT
const COL_MIN_WIDTH = 70

function FilterLink({filterQuery, onClick, children}) {
  const className = classNames('max-w-max w-full flex md:overflow-hidden', {
    'hover:underline': !!filterQuery
  })
  
  if (filterQuery) {
    return (
      <Link
        to={{search: filterQuery.toString()}}
        onClick={onClick}
        className={className}
        >
        { children }
      </Link>
    )
  } else {
    return <span className={className}>{ children }</span>
  }
}

function ExternalLink({item, externalLinkDest}) {
  const dest = externalLinkDest && externalLinkDest(item)
  if (dest) {
    return (
      <a
        target="_blank"
        rel="noreferrer"
        href={dest}
        className="w-4 h-4 hidden group-hover:block"
      >
        <svg className="inline w-full h-full ml-1 -mt-1 text-gray-600 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
      </a>
    )
  }

  return null
}

// The main function component for rendering list reports and making them react to what
// is happening on the dashboard.

// A `fetchData` function must be passed through props. This function defines the format
// of the data, which is expected to be a list of objects. Think of these objects as rows
// with keys being columns. The number of columns is dynamic and should be configured
// via the `metrics` input list. For example:

// | keyLabel           |            METRIC_1.label |            METRIC_2.label | ...
// |--------------------|---------------------------|---------------------------|-----
// | LISTITEM_1.name    | LISTITEM_1[METRIC_1.name] | LISTITEM_1[METRIC_2.name] | ...
// | LISTITEM_2.name    | LISTITEM_2[METRIC_1.name] | LISTITEM_2[METRIC_2.name] | ...

// Further configuration of the report is possible through optional props.

// REQUIRED PROPS:

//   * `keyLabel` - What each entry in the list represents (for UI only).

//   * `query` - The query object representing the current state of the dashboard.

//   * `fetchData` - a function that returns an `api.get` promise that will resolve to the
//     list of data.

//   * `metrics` - a list of `metric` objects. Each `metric` object is required to have at
//     least the `name` and the `label` keys. If the metric should have a different label
//     in realtime or goal-filtered views, we'll use `realtimeLabel` and `GoalFilterLabel`.

//   * `getFilterFor` - a function that takes a list item and returns the query link (with
//      the filter) to navigate to when this list item is clicked. If a list item is not
//      supposed to be clickable, this function should return `null` for that list item.

// OPTIONAL PROPS:

//   * `onClick` - function with additional action to be taken when a list entry is clicked.

//   * `detailsLink` - the pathname to the detailed view of this report. E.g.:
//     `/dummy.site/pages`

//   * `externalLinkDest` - a function that takes a list item and returns an external url
//     to navigate to. If this prop is given, an additional icon is rendered upon hovering
//     the entry.

//   * `renderIcon` - a function that takes a list item and returns the
//     HTML of an icon (such as a flag, favicon, or a screen size icon) for a listItem.

//   * `color` - color of the comparison bars in light-mode

export default function ListReport(props) {
  const [state, setState] = useState({loading: true, list: null})
  const [visible, setVisible] = useState(false)
  const metrics = props.metrics

  const isRealtime = props.query.period === 'realtime'
  const goalFilterApplied = !!props.query.filters.goal

  const fetchData = useCallback(() => {
      if (!isRealtime) {
        setState({loading: true, list: null})
      }
      props.fetchData()
        .then((res) => setState({loading: false, list: res}))
    }, [props.query])

  const onVisible = () => { setVisible(true) }

  useEffect(() => {
    if (isRealtime) {
      // When a goal filter is applied or removed, we always want the component to go into a
      // loading state, even in realtime mode, because the metrics list will change. We can
      // only read the new metrics once the new list is loaded.
      setState({loading: true, list: null})
    }
  }, [goalFilterApplied]);

  useEffect(() => {
    if (visible) {
      if (isRealtime) { document.addEventListener('tick', fetchData) }
      fetchData()
    }

    return () => { document.removeEventListener('tick', fetchData) }
  }, [props.query, visible]);

  function renderReport() {
    if (state.list && state.list.length > 0) {
      return (
        <div className="h-full flex flex-col">
          <div style={{height: ROW_HEIGHT}}>
            { renderReportHeader() }
          </div>

          <div style={{minHeight: DATA_CONTAINER_HEIGHT}}>
            { renderReportBody() }
          </div>

          { maybeRenderMoreLink() }
        </div>
      )
    }
    return renderNoDataYet()
  }

  function renderReportHeader() {
    const metricLabels = metrics.map((metric) => {
      return (<span key={metric.name} className="text-right" style={{minWidth: COL_MIN_WIDTH}}>{ metricLabelFor(metric, props.query) }</span>)
    })
    
    return (
      <div className="pt-3 w-full text-xs font-bold tracking-wide text-gray-500 flex items-center dark:text-gray-400">
        <span className="flex-grow">{ props.keyLabel }</span>
        { metricLabels }
      </div>
    )
  }

  function renderReportBody() {
    return (
      <FlipMove className="flex-grow">
        {state.list.map(renderRow)}
      </FlipMove>
    )
  }

  function renderRow(listItem) {
    return (
      <div key={listItem.name} style={{minHeight: ROW_HEIGHT}}>
        <div className="flex w-full" style={{marginTop: ROW_GAP_HEIGHT}}>
          { renderBarFor(listItem) }
          { renderMetricValuesFor(listItem) }
        </div>
      </div>
    )
  }

  function getFilterQuery(listItem) {
    const filter = props.getFilterFor(listItem)
    if (!filter) { return null }
    
    const query = new URLSearchParams(window.location.search)
    Object.entries(filter).forEach((([key, value]) => {
      query.set(key, value)
    }))

    return query
  }

  function renderBarFor(listItem) {    
    const lightBackground = props.color || 'bg-green-50'
    const noop = () => {}
    const metricToPlot = metrics[0].name

    return (
      <div className="flex-grow w-full overflow-hidden">
        <Bar
          count={listItem[metricToPlot]}
          all={state.list}
          bg={`${lightBackground} dark:bg-gray-500 dark:bg-opacity-15`}
          plot={metricToPlot}
        >
          <div className="flex justify-start px-2 py-1.5 group text-sm dark:text-gray-300 relative z-9 break-all w-full">
            <FilterLink filterQuery={getFilterQuery(listItem)} onClick={props.onClick || noop}>
              {maybeRenderIconFor(listItem)}

              <span className="w-full md:truncate">
                {listItem.name}
              </span>
            </FilterLink>
            <ExternalLink item={listItem} externalLinkDest={props.externalLinkDest} />
          </div>
        </Bar>
      </div>
    )
  }

  function maybeRenderIconFor(listItem) {
    if (props.renderIcon) {
      return (
        <span className="pr-1">
          {props.renderIcon(listItem)}
        </span>
      )
    }
  }

  function renderMetricValuesFor(listItem) {
    return metrics.map((metric) => {
      return (
        <div key={`${listItem.name}__${metric.name}`} style={{width: COL_MIN_WIDTH, minWidth: COL_MIN_WIDTH}} className="text-right">
          <span className="font-medium text-sm dark:text-gray-200 text-right">
            { displayMetricValue(listItem[metric.name], metric) }
          </span>
        </div>
      )
    })
  }

  function renderLoading() {
    return (
      <div className="w-full flex flex-col justify-center" style={{minHeight: `${MIN_HEIGHT}px`}}>
        <div className="mx-auto loading"><div></div></div>
      </div>
    )
  }

  function renderNoDataYet() {
    return (
      <div className="w-full h-full flex flex-col justify-center" style={{minHeight: `${MIN_HEIGHT}px`}}>
        <div className="mx-auto font-medium text-gray-500 dark:text-gray-400">No data yet</div>
      </div>
    )
  }

  function maybeRenderMoreLink() {
    return props.detailsLink && !state.loading && <MoreLink url={props.detailsLink} list={state.list}/>
  }

  return (
    <LazyLoader onVisible={onVisible} >
      <div className="w-full" style={{minHeight: `${MIN_HEIGHT}px`}}>
        { state.loading && renderLoading() }  
        <FadeIn show={!state.loading} className="h-full">
          { renderReport() }
        </FadeIn>
      </div>
    </LazyLoader>
  )
}
