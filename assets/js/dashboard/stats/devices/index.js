import React from 'react';

import * as storage from '../../util/storage'
import ListReport from '../reports/list'
import * as api from '../../api'
import * as url from '../../util/url'
import { VISITORS_METRIC, PERCENTAGE_METRIC, maybeWithCR } from '../reports/metrics';

function Browsers({ query, site }) {
  function fetchData() {
    return api.get(url.apiPath(site, '/browsers'), query)
  }

  function getFilterFor(listItem) {
    return { browser: listItem['name']}
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel="Browser"
      metrics={maybeWithCR([VISITORS_METRIC, PERCENTAGE_METRIC], query)}
      query={query}
    />
  )
}

function BrowserVersions({ query, site }) {
  function fetchData() {
    return api.get(url.apiPath(site, '/browser-versions'), query)
  }

  function getFilterFor(listItem) {
    if (query.filters.browser === '(not set)') {
      return {}
    }
    return { browser_version: listItem['name']}
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel="Browser version"
      metrics={maybeWithCR([VISITORS_METRIC, PERCENTAGE_METRIC], query)}
      query={query}
    />
  )

}

function OperatingSystems({ query, site }) {
  function fetchData() {
    return api.get(url.apiPath(site, '/operating-systems'), query)
  }

  function getFilterFor(listItem) {
    return { os: listItem['name']}
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel="Operating system"
      metrics={maybeWithCR([VISITORS_METRIC, PERCENTAGE_METRIC], query)}
      query={query}
    />
  )
}

function OperatingSystemVersions({ query, site }) {
  function fetchData() {
    return api.get(url.apiPath(site, '/operating-system-versions'), query)
  }

  function getFilterFor(listItem) {
    if (query.filters.os === '(not set)') {
      return {}
    }
    return { os_version: listItem['name']}
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel="Operating System Version"
      metrics={maybeWithCR([VISITORS_METRIC, PERCENTAGE_METRIC], query)}
      query={query}
    />
  )

}

function ScreenSizes({ query, site }) {
  function fetchData() {
    return api.get(url.apiPath(site, '/screen-sizes'), query)
  }

  function renderIcon(screenSize) {
    return iconFor(screenSize.name)
  }

  function getFilterFor(listItem) {
    return { screen: listItem['name']}
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel="Screen size"
      metrics={maybeWithCR([VISITORS_METRIC, PERCENTAGE_METRIC], query)}
      query={query}
      renderIcon={renderIcon}
    />
  )
}

function iconFor(screenSize) {
  if (screenSize === 'Mobile') {
    return (
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="5" y="2" width="14" height="20" rx="2" ry="2" /><line x1="12" y1="18" x2="12" y2="18" /></svg>
    )
  } else if (screenSize === 'Tablet') {
    return (
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="4" y="2" width="16" height="20" rx="2" ry="2" transform="rotate(180 12 12)" /><line x1="12" y1="18" x2="12" y2="18" /></svg>
    )
  } else if (screenSize === 'Laptop') {
    return (
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="2" y="3" width="20" height="14" rx="2" ry="2" /><line x1="2" y1="20" x2="22" y2="20" /></svg>
    )
  } else if (screenSize === 'Desktop') {
    return (
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="2" y="3" width="20" height="14" rx="2" ry="2" /><line x1="8" y1="21" x2="16" y2="21" /><line x1="12" y1="17" x2="12" y2="21" /></svg>
    )
  } else if (screenSize === '(not set)') {
    return null
  }
}

export default class Devices extends React.Component {
  constructor(props) {
    super(props)
    this.tabKey = `deviceTab__${props.site.domain}`
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || 'browser'
    }
  }

  setMode(mode) {
    return () => {
      storage.setItem(this.tabKey, mode)
      this.setState({ mode })
    }
  }

  renderContent() {
    switch (this.state.mode) {
      case 'browser':
        if (this.props.query.filters.browser) {
          return <BrowserVersions site={this.props.site} query={this.props.query} />
        }
        return <Browsers site={this.props.site} query={this.props.query} />
      case 'os':
        if (this.props.query.filters.os) {
          return <OperatingSystemVersions site={this.props.site} query={this.props.query} />
        }
        return <OperatingSystems site={this.props.site} query={this.props.query} />
      case 'size':
      default:
        return (
          <ScreenSizes site={this.props.site} query={this.props.query} />
        )
    }
  }

  renderPill(name, mode) {
    const isActive = this.state.mode === mode

    if (isActive) {
      return (
        <button
          className="inline-block h-5 font-bold text-indigo-700 active-prop-heading dark:text-indigo-500"
        >
          {name}
        </button>
      )
    }

    return (
      <button
        className="cursor-pointer hover:text-indigo-600"
        onClick={this.setMode(mode)}
      >
        {name}
      </button>
    )
  }

  render() {
    return (
      <div>
        <div className="flex justify-between w-full">
          <h3 className="font-bold dark:text-gray-100">Devices</h3>
          <div className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
            {this.renderPill('Browser', 'browser')}
            {this.renderPill('OS', 'os')}
            {this.renderPill('Size', 'size')}
          </div>
        </div>
        {this.renderContent()}
      </div>
    )
  }
}
