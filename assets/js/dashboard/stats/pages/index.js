import React from 'react';

import * as storage from '../../storage'
import Visits from './pages'
import EntryPages from './entry-pages'
import ExitPages from './exit-pages'

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
      return <Visits site={this.props.site} query={this.props.query} timer={this.props.timer} />
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
          className="stats-item__header flex flex-col flex-grow bg-white dark:bg-gray-825 shadow-xl rounded p-4 relative"
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
