import React, { useState, useEffect, useRef } from 'react';
import { Link } from 'react-router-dom'

import FadeIn from '../../fade-in'
import MoreLink from '../more-link'
import numberFormatter from '../../util/number-formatter'
import Bar from '../bar'
import LazyLoader from '../../components/lazy-loader'

function ExternalLink({item, externalLinkDest}) {
  if (externalLinkDest) {
    const dest = externalLinkDest(item)

    return (
      <a
        target="_blank"
        rel="noreferrer"
        href={dest}
        className="hidden group-hover:block"
      >
        <svg className="inline w-4 h-4 ml-1 -mt-1 text-gray-600 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
      </a>
    )
  }

  return null
}

export default function ListReport(props) {
  const [state, setState] = useState({loading: true, list: null})
  const valueKey = props.valueKey || 'visitors'
  const showConversionRate = !!props.query.filters.goal
  const prevQuery = useRef();

  function fetchData() {
    if (typeof(prevQuery.current) === 'undefined' || prevQuery.current !== props.query) {
      prevQuery.current = props.query;
      setState({loading: true, list: null})
      props.fetchData()
        .then((res) => setState({loading: false, list: res}))
    }
  }


  function onVisible() {
    fetchData()
    if (props.timer) props.timer.onTick(fetchData)
  }


  function label() {
    if (props.query.period === 'realtime') {
      return 'Current visitors'
    }

    if (showConversionRate) {
      return 'Conversions'
    }

    return props.valueLabel || 'Visitors'
  }

  useEffect(fetchData, [props.query]);

  function renderListItem(listItem) {
    const query = new URLSearchParams(window.location.search)

    Object.entries(props.filter).forEach((([key, valueKey]) => {
      query.set(key, listItem[valueKey])
    }))

    const maxWidthDeduction =  showConversionRate ? "10rem" : "5rem"
    const lightBackground = props.color || 'bg-green-50'
    const noop = () => {}

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={listItem.name}>
        <Bar
          count={listItem[valueKey]}
          all={state.list}
          bg={`${lightBackground} dark:bg-gray-500 dark:bg-opacity-15`}
          maxWidthDeduction={maxWidthDeduction}
          plot={valueKey}
        >
          <span className="flex px-2 py-1.5 group dark:text-gray-300 relative z-9 break-all" tooltip={props.tooltipText && props.tooltipText(listItem)}>
            <Link onClick={props.onClick || noop} className="md:truncate block hover:underline" to={{search: query.toString()}}>
              {props.renderIcon && props.renderIcon(listItem)}
              {props.renderIcon && ' '}
              {listItem.name}
            </Link>
            <ExternalLink item={listItem} externalLinkDest={props.externalLinkDest}  />
          </span>
        </Bar>
        <span className="font-medium dark:text-gray-200 w-20 text-right">
          {numberFormatter(listItem[valueKey])}
          {
            listItem.percentage >= 0
              ? <span className="inline-block w-8 pl-1 text-xs text-right">({listItem.percentage}%)</span>
              : null
          }
        </span>
        {showConversionRate && <span className="font-medium dark:text-gray-200 w-20 text-right">{listItem.conversion_rate}%</span>}
      </div>
    )
  }

  function renderList() {
    if (state.list && state.list.length > 0) {
      return (
        <>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>{ props.keyLabel }</span>
            <span className="text-right">
              <span className="inline-block w-30">{label()}</span>
              {showConversionRate && <span className="inline-block w-20">CR</span>}
            </span>
          </div>
          { state.list && state.list.map(renderListItem) }
        </>
      )
    }

    return <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">No data yet</div>
  }

  return (
    <LazyLoader onVisible={onVisible} className="flex flex-col flex-grow">
      { state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
      <FadeIn show={!state.loading} className="flex-grow">
        { renderList() }
      </FadeIn>
      {props.detailsLink && !state.loading && <MoreLink url={props.detailsLink} list={state.list} />}
    </LazyLoader>
  )
}
