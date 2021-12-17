import React from 'react';

import * as storage from '../../util/storage'
import * as url from '../../util/url'
import * as api from '../../api'
import ListReport from './../reports/list'

function EntryPages({query, site}) {
  function fetchData() {
    return api.get(url.apiPath(site, '/entry-pages'), query, {limit: 9})
  }

  function externalLinkDest(page) {
    return url.externalLinkForPage(site.domain, page.name)
  }

  return (
    <ListReport
      fetchData={fetchData}
      filter={{entry_page: 'name'}}
      keyLabel="Entry page"
      valueLabel="Unique Entrances"
      valueKey="unique_entrances"
      detailsLink={url.sitePath(site, '/entry-pages')}
      query={query}
      externalLinkDest={externalLinkDest}
      color="bg-orange-50"
    />
  )
}

function ExitPages({query, site}) {
  function fetchData() {
    return api.get(url.apiPath(site, '/exit-pages'), query, {limit: 9})
  }

  function externalLinkDest(page) {
    return url.externalLinkForPage(site.domain, page.name)
  }

  return (
    <ListReport
      fetchData={fetchData}
      filter={{exit_page: 'name'}}
      keyLabel="Exit page"
      valueLabel="Unique Exits"
      valueKey="unique_exits"
      detailsLink={url.sitePath(site, '/exit-pages')}
      query={query}
      externalLinkDest={externalLinkDest}
      color="bg-orange-50"
    />
  )
}

function TopPages({query, site}) {
  function fetchData() {
    return api.get(url.apiPath(site, '/pages'), query, {limit: 9})
  }

  function externalLinkDest(page) {
    return url.externalLinkForPage(site.domain, page.name)
  }

  return (
    <ListReport
      fetchData={fetchData}
      filter={{page: 'name'}}
      keyLabel="Page"
      detailsLink={url.sitePath(site, '/pages')}
      query={query}
      externalLinkDest={externalLinkDest}
      color="bg-orange-50"
    />
  )
}

const labelFor = {
	'pages': 'Top Pages',
	'entry-pages': 'Entry Pages',
	'exit-pages': 'Exit Pages',
}

export default class Pages extends React.Component {
  constructor(props) {
    super(props)
    this.tabKey = `pageTab__${  props.site.domain}`
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || 'pages'
    }
  }

  setMode(mode) {
    return () => {
      storage.setItem(this.tabKey, mode)
      this.setState({mode})
    }
  }

  renderContent() {
    switch(this.state.mode) {
    case "entry-pages":
      return <EntryPages site={this.props.site} query={this.props.query} timer={this.props.timer} />
    case "exit-pages":
      return <ExitPages site={this.props.site} query={this.props.query} timer={this.props.timer} />
    case "pages":
    default:
      return <TopPages site={this.props.site} query={this.props.query} timer={this.props.timer} />
    }
  }


  renderPill(name, mode) {
    const isActive = this.state.mode === mode

    if (isActive) {
      return (
        <li
          className="inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading"
        >
          {name}
        </li>
      )
    }

    return (
      <li
        className="hover:text-indigo-600 cursor-pointer"
        onClick={this.setMode(mode)}
      >
        {name}
      </li>
    )
  }

  render() {
    return (
      <div
        className="stats-item flex flex-col w-full mt-6 stats-item--has-header"
      >
        <div
          className="stats-item-header flex flex-col flex-grow bg-white dark:bg-gray-825 shadow-xl rounded p-4 relative"
        >
          {/* Header Container */}
          <div className="w-full flex justify-between">
            <h3 className="font-bold dark:text-gray-100">
              {labelFor[this.state.mode] || 'Page Visits'}
            </h3>
            <ul className="flex font-medium text-xs text-gray-500 dark:text-gray-400 space-x-2">
              { this.renderPill('Top Pages', 'pages') }
              { this.renderPill('Entry Pages', 'entry-pages') }
              { this.renderPill('Exit Pages', 'exit-pages') }
            </ul>
          </div>
          {/* Main Contents */}
          { this.renderContent() }
        </div>
      </div>
    )
  }
}
