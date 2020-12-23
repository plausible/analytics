import React, { useState, useEffect } from 'react';
import { withRouter } from 'react-router-dom'
import {countFilters, navigateToQuery, removeQueryParam} from './query'
import Datamap from 'datamaps'
import Transition from "../transition.js";
import { useScreenClass } from './screenclass-hook';

function filterText(key, value, query) {
  if (key === "goal") {
    return <span className="inline-block max-w-2xs truncate">Completed goal <b>{value}</b></span>
  }
  if (key === "props") {
    const [metaKey, metaValue] = Object.entries(value)[0]
    const eventName = query.filters["goal"] ? query.filters["goal"] : 'event'
    return <span className="inline-block max-w-2xs truncate">{eventName}.{metaKey} is <b>{metaValue}</b></span>
  }
  if (key === "source") {
    return <span className="inline-block max-w-2xs truncate">Source: <b>{value}</b></span>
  }
  if (key === "utm_medium") {
    return <span className="inline-block max-w-2xs truncate">UTM medium: <b>{value}</b></span>
  }
  if (key === "utm_source") {
    return <span className="inline-block max-w-2xs truncate">UTM source: <b>{value}</b></span>
  }
  if (key === "utm_campaign") {
    return <span className="inline-block max-w-2xs truncate">UTM campaign: <b>{value}</b></span>
  }
  if (key === "referrer") {
    return <span className="inline-block max-w-2xs truncate">Referrer: <b>{value}</b></span>
  }
  if (key === "screen") {
    return <span className="inline-block max-w-2xs truncate">Screen size: <b>{value}</b></span>
  }
  if (key === "browser") {
    return <span className="inline-block max-w-2xs truncate">Browser: <b>{value}</b></span>
  }
  if (key === "browser_version") {
    const browserName = query.filters["browser"] ? query.filters["browser"] : 'Browser'
    return <span className="inline-block max-w-2xs truncate">{browserName}.Version: <b>{value}</b></span>
  }
  if (key === "os") {
    return <span className="inline-block max-w-2xs truncate">Operating System: <b>{value}</b></span>
  }
  if (key === "os_version") {
    const osName = query.filters["os"] ? query.filters["os"] : 'OS'
    return <span className="inline-block max-w-2xs truncate">{osName}.Version: <b>{value}</b></span>
  }
  if (key === "country") {
    const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
    const selectedCountry = allCountries.find((c) => c.id === value)
    return <span className="inline-block max-w-2xs truncate">Country: <b>{selectedCountry.properties.name}</b></span>
  }
  if (key === "page") {
    return <span className="inline-block max-w-2xs truncate">Page: <b>{value}</b></span>
  }
}

function renderFilter(history, [key, value], query, wrapped) {
  function removeFilter() {
    const newOpts = {
      [key]: false
    }
    if (key === 'goal') { newOpts.props = false }
    navigateToQuery(
      history,
      query,
      newOpts
    )
  }

  return wrapped ? (
    <div className="px-4 py-2 text-sm leading-tight flex items-center justify-between" key={key+value}>
      {filterText(key, value, query)}
      <b className="ml-1 cursor-pointer hover:text-indigo-500" onClick={removeFilter}>✕</b>
    </div>
  ) : (
    <span key={key} title={value} className="inline-flex bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 shadow text-sm rounded py-2 px-3 mr-2">
      {filterText(key, value, query)} <b className="ml-1 cursor-pointer hover:text-indigo-500" onClick={removeFilter}>✕</b>
    </span>
  )
}

function Filters({query, history, location}) {
  const [open, setOpen] = useState(false)
  const [wrapped, setWrapped] = useState(false)
  const screenClass = useScreenClass();
  let dropDownNode
  const appliedFilters = Object.keys(query.filters)
    .map((key) => [key, query.filters[key]])
    .filter(([key, value]) => !!value)

  useEffect(() => {
    document.addEventListener('mousedown', handleClick, false);
    return () => {
      document.removeEventListener('mousedown', handleClick, false);
    }
  }, [])

  useEffect(() => {
    const rewrapFilters = () => {
      let currItem, prevItem, items = document.getElementById('filters_row');
      if (!items) { return };

      setWrapped(false);
      [...(items.childNodes)].forEach(item => {
        currItem = item.getBoundingClientRect();
        if (prevItem && prevItem.top < currItem.top) {
          setWrapped(true);
        }
        prevItem = currItem;
      });
    };

    rewrapFilters();

    window.addEventListener('resize', rewrapFilters);
    return () => {window.removeEventListener('resize', rewrapFilters); }
  }, [appliedFilters.length])

  const handleClick = (e) => {
    if (dropDownNode && dropDownNode.contains(e.target)) return;

    setOpen(false)
  }

  const renderDropDown = () => {
    return (
      <div id="filters_row">
        { wrapped || screenClass === 'sm' ? (
          <div className="relative" style={{ height: '35.5px', width: '160px' }}>
            <div onClick={() => setOpen(!open)} className="flex items-center justify-between rounded bg-white dark:bg-gray-800 shadow px-4 pr-3 py-2 leading-tight cursor-pointer text-sm font-medium text-gray-800 dark:text-gray-200 h-full">
              <span className="mr-2">Active Filters</span>
              <svg className="text-pink-500 h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="6 9 12 15 18 9"></polyline>
              </svg>
            </div>
            <Transition
              show={open}
              enter="transition ease-out duration-100 transform"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="transition ease-in duration-75 transform"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              {renderDropDownContent(wrapped || screenClass === 'sm')}
            </Transition>
          </div>) :
          (appliedFilters.map((filter) => renderFilter(history, filter, query, wrapped || screenClass === 'sm')))
        }
      </div>
    )
  }

  const renderDropDownContent = (wrapped) => {
    return (
      <div className="absolute mt-2 rounded shadow-md z-10" style={{width: '235px', right: '-14px'}} ref={node => dropDownNode = node}>
        <div className="rounded bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 font-medium text-gray-800 dark:text-gray-200 flex flex-col">
          { appliedFilters.map((filter) => renderFilter(history, filter, query, wrapped)) }

          <div className="border-t border-gray-200 dark:border-gray-500" />
          <div className="px-4 py-2 text-sm leading-tight hover:text-indigo-500 hover:cursor-pointer">
            Clear All Filters
          </div>
        </div>
      </div>
    )
  }

  if (appliedFilters.length > 0) {
    return (
      renderDropDown()
    )
  }

  return null
}

export default withRouter(Filters)
