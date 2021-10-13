import React from 'react';

import * as storage from '../../storage'
import Countries from './countries';
import CountriesMap from './map'

const labelFor = {
	'map': 'Countries Map',
	'countries': 'Countries',
	'regions': 'Regions',
	'cities': 'Cities',
}

export default class Locations extends React.Component {
	constructor(props) {
    super(props)
    this.tabKey = `geoTab__${  props.site.domain}`
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || 'map'
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
		case "countries":
      return <Countries site={this.props.site} query={this.props.query} timer={this.props.timer}/>
    case "map":
    default:
      return <CountriesMap site={this.props.site} query={this.props.query} timer={this.props.timer}/>
    }
  }

	renderPill(name, mode) {
    const isActive = this.state.mode === mode

    if (isActive) {
      return (
        <li
          className="inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold border-b-2 border-indigo-700 dark:border-indigo-500"
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
          <div className="w-full flex justify-between">
            <h3 className="font-bold dark:text-gray-100">
              {labelFor[this.state.mode] || 'Locations'}
            </h3>
            <ul className="flex font-medium text-xs text-gray-500 dark:text-gray-400 space-x-2">
              { this.renderPill('Map', 'map') }
              { this.renderPill('Countries', 'countries') }
              {/* { this.renderPill('Regions', 'regions') } */}
              {/* { this.renderPill('Cities', 'cities') } */}
            </ul>
          </div>
          { this.renderContent() }
        </div>
      </div>
    )
  }
}
