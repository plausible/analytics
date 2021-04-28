import React from 'react';
import { Link } from 'react-router-dom'

import * as storage from '../../storage'
import Visits from './pages'
import EntryPages from './entry-pages'
import ExitPages from './exit-pages'
import FadeIn from '../../fade-in'

const labelFor = {
	'pages': 'Top Pages',
	'entry-pages': 'Entry Pages',
	'exit-pages': 'Exit Pages',
}

export default class Pages extends React.Component {
  constructor(props) {
    super(props)
    this.tabKey = 'pageTab__' + props.site.domain
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || 'pages'
    }
  }

  renderContent() {
    if (this.state.mode === 'pages') {
      return <Visits site={this.props.site} query={this.props.query} timer={this.props.timer} />
    } else if (this.state.mode === 'entry-pages') {
      return <EntryPages site={this.props.site} query={this.props.query} timer={this.props.timer} />
    } else if (this.state.mode === 'exit-pages') {
      return <ExitPages site={this.props.site} query={this.props.query} timer={this.props.timer} />
    }
  }

  setMode(mode) {
    return () => {
      storage.setItem(this.tabKey, mode)
      this.setState({mode})
    }
  }

  renderPill(name, mode) {
    const isActive = this.state.mode === mode

    if (isActive) {
      return <li className="inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold border-b-2 border-indigo-700 dark:border-indigo-500">{name}</li>
    } else {
      return <li className="hover:text-indigo-600 cursor-pointer" onClick={this.setMode(mode)}>{name}</li>
    }
  }

  render() {
		const filters = this.props.query.filters
    return (
      <div className="stats-item">
        <div className="bg-white dark:bg-gray-825 shadow-xl rounded p-4 relative" style={{height: '436px'}}>

          <div className="w-full flex justify-between">
            <h3 className="font-bold dark:text-gray-100">{labelFor[this.state.mode] || 'Page Visits'}</h3>

            <ul className="flex font-medium text-xs text-gray-500 dark:text-gray-400 space-x-2">
              { this.renderPill('Top Pages', 'pages') }
              { this.renderPill('Entry Pages', 'entry-pages') }
              { this.renderPill('Exit Pages', 'exit-pages') }
            </ul>
          </div>

          { this.renderContent() }

        </div>
      </div>
    )
  }
}
