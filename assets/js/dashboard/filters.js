import React from 'react';
import { withRouter, Link } from 'react-router-dom'
import classNames from 'classnames'
import Datamap from 'datamaps'
import { XIcon, PlusIcon } from '@heroicons/react/solid'
import { Transition } from '@headlessui/react'
import Collapse from "@kunukn/react-collapse";

import { formattedFilters, navigateToQuery } from './query'
import { filterGroupForFilter } from './stats/modals/filter'
import Datepicker from './datepicker'
import { FilterDropdown } from './filter-selector'

class Filters extends React.Component {
  constructor(props) {
    super(props);

    this.handleResize = this.handleResize.bind(this)
    this.state = {viewport: window.innerWidth}
  }

  componentDidMount() {
    window.addEventListener('resize', this.handleResize, false);
  }

  componentWillUnmount() {
    window.removeEventListener('resize', this.handleResize, false);
  }

  handleResize() {
    this.setState({viewport: window.innerWidth});
  }

  appliedFilters() {
    return Object.keys(this.props.query.filters)
      .map((key) => [key, this.props.query.filters[key]])
      .filter(([key, value]) => !!value)
  }

  filterText(key, value, query) {
    const negated = value[0] == '!' && ['page', 'entry_page', 'exit_page'].includes(key)
    value = negated ? value.slice(1) : value

    if (key === "goal") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Completed goal <b>{value}</b></span>
    }
    if (key === "props") {
      const [metaKey, metaValue] = Object.entries(value)[0]
      const eventName = query.filters["goal"] ? query.filters["goal"] : 'event'
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">{eventName}.{metaKey} is <b>{metaValue}</b></span>
    }
    if (key === "source") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Source is <b>{value}</b></span>
    }
    if (key === "utm_medium") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">UTM medium is <b>{value}</b></span>
    }
    if (key === "utm_source") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">UTM source is <b>{value}</b></span>
    }
    if (key === "utm_campaign") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">UTM campaign is <b>{value}</b></span>
    }
    if (key === "referrer") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Referrer URL is <b>{value}</b></span>
    }
    if (key === "screen") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Screen size is <b>{value}</b></span>
    }
    if (key === "browser") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Browser is <b>{value}</b></span>
    }
    if (key === "browser_version") {
      const browserName = query.filters["browser"] ? query.filters["browser"] : 'Browser'
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">{browserName} Version is <b>{value}</b></span>
    }
    if (key === "os") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Operating System is <b>{value}</b></span>
    }
    if (key === "os_version") {
      const osName = query.filters["os"] ? query.filters["os"] : 'OS'
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">{osName} Version is <b>{value}</b></span>
    }
    if (key === "country") {
      const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
      const selectedCountry = allCountries.find((c) => c.id === value) || { properties: { name: value } };
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Country is <b>{selectedCountry.properties.name}</b></span>
    }
    if (key === "page") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Page is{negated ? ' not' : ''} <b>{value}</b></span>
    }
    if (key === "entry_page") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Entry Page is{negated ? ' not' : ''} <b>{value}</b></span>
    }
    if (key === "exit_page") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Exit Page is{negated ? ' not' : ''} <b>{value}</b></span>
    }
  }

  removeFilter(key, history, query) {
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

  renderListFilter([key, value]) {
    const { history, query} = this.props;

    return (
      <span key={key} title={value} className="flex bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 shadow text-xs md:text-sm rounded mr-1 md:mr-2 items-center my-1">
        {'props' == key ? (
          <span className="flex w-full h-full items-center py-2 pl-3">
            {this.filterText(key, value, query)}
          </span>
        ) : (
          <>
            <Link title={`Edit filter: ${formattedFilters[key]}`} className="flex w-full h-full items-center py-2 pl-3" to={{ pathname: `/${encodeURIComponent(this.props.site.domain)}/filter/${filterGroupForFilter(key)}`, search: window.location.search }}>
              {this.filterText(key, value, query)}
            </Link>
            <span className="hidden h-full w-full px-2 cursor-pointer text-indigo-700 dark:text-indigo-500 items-center">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="1 1 23 23" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
            </span>
          </>
        )}
        <span title={`Remove filter: ${formattedFilters[key]}`} className="flex h-full px-1 md:px-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 items-center" onClick={() => this.removeFilter(key, history, query)}>
          <XIcon className="w-4 h-4 md:w-5 md:h-5 text-gray-500" />
        </span>
      </span>
    )
  }

  isMediumScreenOrLess() {
    return this.state.viewport < 768
  }

  clearAllFilters(history, query) {
    const newOpts = Object.keys(query.filters).reduce((acc, red) => ({ ...acc, [red]: false }), {});
    navigateToQuery(
      history,
      query,
      newOpts
    );
  }

  render() {
    if (this.isMediumScreenOrLess()) {
      return (
        <Collapse isOpen={this.props.mobileFiltersOpen} transition={`height 280ms cubic-bezier(.4, 0, .2, 1)`}>
          <div id="filters" className={classNames('flex-grow flex-wrap', this.props.className)}>
            <Datepicker leadingText="Daterange: " className="mr-1 my-1" site={this.props.site} query={this.props.query} />
            {
              this.appliedFilters().map((filter) => this.renderListFilter(filter))
            }

            <FilterDropdown className="inline-block my-1" site={this.props.site} />
          </div>
        </Collapse>
      )
    } else if (this.appliedFilters().length > 0) {
      return (
        <div id="filters" className={classNames('flex-grow flex-wrap', this.props.className)}>
          { this.appliedFilters().map((filter) => this.renderListFilter(filter)) }
        </div>
      )
    }

    return null
  }
}

export default withRouter(Filters);
