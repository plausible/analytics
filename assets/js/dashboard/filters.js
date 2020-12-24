import React, { useState, useEffect, useLayoutEffect } from 'react';
import { withRouter } from 'react-router-dom'
import { countFilters, navigateToQuery, removeQueryParam } from './query'
import Datamap from 'datamaps'
import Transition from "../transition.js";
import { useScreenClass } from './screenclass-hook';

const filterText = (key, value, query) => {
  if (key === "goal") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">Completed goal <b>{value}</b></span>
  }
  if (key === "props") {
    const [metaKey, metaValue] = Object.entries(value)[0]
    const eventName = query.filters["goal"] ? query.filters["goal"] : 'event'
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">{eventName}.{metaKey} is <b>{metaValue}</b></span>
  }
  if (key === "source") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">Source: <b>{value}</b></span>
  }
  if (key === "utm_medium") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">UTM medium: <b>{value}</b></span>
  }
  if (key === "utm_source") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">UTM source: <b>{value}</b></span>
  }
  if (key === "utm_campaign") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">UTM campaign: <b>{value}</b></span>
  }
  if (key === "referrer") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">Referrer: <b>{value}</b></span>
  }
  if (key === "screen") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">Screen size: <b>{value}</b></span>
  }
  if (key === "browser") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">Browser: <b>{value}</b></span>
  }
  if (key === "browser_version") {
    const browserName = query.filters["browser"] ? query.filters["browser"] : 'Browser'
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">{browserName}.Version: <b>{value}</b></span>
  }
  if (key === "os") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">Operating System: <b>{value}</b></span>
  }
  if (key === "os_version") {
    const osName = query.filters["os"] ? query.filters["os"] : 'OS'
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">{osName}.Version: <b>{value}</b></span>
  }
  if (key === "country") {
    const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
    const selectedCountry = allCountries.find((c) => c.id === value)
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">Country: <b>{selectedCountry.properties.name}</b></span>
  }
  if (key === "page") {
    return <span className="inline-block max-w-2xs md:max-w-xs truncate">Page: <b>{value}</b></span>
  }
}

const removeFilter = (key, history, query) => {
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

const renderDropdownFilter = (history, [key, value], query) => {
  return (
    <div className="px-4 sm:py-2 py-3 md:text-sm leading-tight flex items-center justify-between" key={key + value}>
      {filterText(key, value, query)}
      <b className="ml-1 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500" onClick={() => removeFilter(key, history, query)}>✕</b>
    </div>
  )
}

const renderListFilter = (history, [key, value], query) => {
  return (
    <span key={key} title={value} className="inline-flex bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 shadow text-sm rounded py-2 px-3 mr-2">
      {filterText(key, value, query)} <b className="ml-1 cursor-pointer hover:text-indigo-500" onClick={() => removeFilter(key, history, query)}>✕</b>
    </span>
  )
}

const clearAllFilters = (history, query) => {
  const newOpts = Object.keys(query.filters).reduce((acc, red) => ({ ...acc, [red]: false }), {});
  navigateToQuery(
    history,
    query,
    newOpts
  );
}

const Filters = ({ query, history, location }) => {
  let dropDownNode;
  const appliedFilters = Object.keys(query.filters)
    .map((key) => [key, query.filters[key]])
    .filter(([key, value]) => !!value)
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [wrapped, setWrapped] = useState(false); // Filter wrap state (true=dropdown, false=list)
  const [recheck, setRecheck] = useState(false); // If there is a pending rewrap check
  const screenClass = useScreenClass();

  // Dropdown auto-close listener
  useEffect(() => {
    const handleClick = (e) => {
      if (dropDownNode && dropDownNode.contains(e.target)) return;

      setDropdownOpen(false)
    };

    document.addEventListener('mousedown', handleClick, false);
    return () => {
      document.removeEventListener('mousedown', handleClick, false);
    }
  }, [])

  // Checks if the filter container is wrapping items
  const rewrapFilters = () => {
    let currItem, prevItem, items = document.getElementById('filters');

    if (wrapped) { return }; // Don't rewrap if we're already wrapped
    if (!items) { return }; // Don't rewrap if there are no filters
    if (appliedFilters.length === 1) { return }; // Don't rewrap if there is only one filter

    // For every filter DOM Node, check if its y value is higher than the previous (this indicates a wrap)
    [...(items.childNodes)].forEach(item => {
      currItem = item.getBoundingClientRect();
      if (prevItem && prevItem.top < currItem.top) {
        setWrapped(true);
      }
      prevItem = currItem;
    });
  };

  // On query change or viewport resize, force a check for if the filters can fit
  useLayoutEffect(() => {
    setWrapped(false);
    setRecheck(true);
  }, [JSON.stringify(query), screenClass]);

  // When a refresh is forced, wait for state changes to propogate, then check if a wrap is needed
  useLayoutEffect(() => {
    setRecheck(false);
    rewrapFilters();
  }, [wrapped, recheck]);

  const renderDropDownContent = () => {
    return (
      <div className="absolute mt-2 rounded shadow-md z-10" style={{ width: screenClass === 'sm' ? '320px' : '350px', right: '-5px' }} ref={node => dropDownNode = node}>
        <div className="rounded bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 font-medium text-gray-800 dark:text-gray-200 flex flex-col">
          {appliedFilters.map((filter) => renderDropdownFilter(history, filter, query))}
          <div className="border-t border-gray-200 dark:border-gray-500 px-4 sm:py-2 py-3 md:text-sm leading-tight hover:text-indigo-700 dark:hover:text-indigo-500 hover:cursor-pointer" onClick={() => clearAllFilters(history, query)}>
            Clear All Filters
          </div>
        </div>
      </div>
    )
  }

  const renderDropDown = () => {
    return (
      <div id="filters" className='ml-auto'>
        <div className="relative" style={{ height: '35.5px', width: '100px' }}>
          <div onClick={() => setDropdownOpen(!dropdownOpen)} className="flex items-center justify-between rounded bg-white dark:bg-gray-800 shadow px-4 pr-3 py-2 leading-tight cursor-pointer text-sm font-medium text-gray-800 dark:text-gray-200 h-full">
            <span className="mr-2">Filters</span>
            <svg className="text-pink-500 h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="6 9 12 15 18 9"></polyline>
            </svg>
          </div>
          <Transition
            show={dropdownOpen}
            enter="transition ease-out duration-100 transform"
            enterFrom="opacity-0 scale-95"
            enterTo="opacity-100 scale-100"
            leave="transition ease-in duration-75 transform"
            leaveFrom="opacity-100 scale-100"
            leaveTo="opacity-0 scale-95"
          >
            {renderDropDownContent()}
          </Transition>
        </div>
      </div>
    );
  }

  const renderFilterList = () => {
    return (
      <div id="filters">
        {(appliedFilters.map((filter) => renderListFilter(history, filter, query)))}
      </div>
    );
  }

  if (appliedFilters.length > 0) {
    if (wrapped || screenClass === 'sm') {
      return renderDropDown();
    }

    return renderFilterList();
  }

  return null;
}

export default withRouter(Filters);
