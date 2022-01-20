import React from 'react';

import * as storage from '../../util/storage'
import CountriesMap from './map'

import * as api from '../../api'
import {apiPath, sitePath} from '../../util/url'
import ListReport from '../reports/list'

function Countries({query, site, onClick}) {
  function fetchData() {
    return api.get(apiPath(site, '/countries'), query, {limit: 9}).then((res) => {
      return res.map(row => Object.assign({}, row, {percentage: undefined}))
    })
  }

  function renderIcon(country) {
    return <span className="mr-1">{country.flag}</span>
  }

  return (
    <ListReport
      fetchData={fetchData}
      filter={{country: 'code', country_name: 'name'}}
      onClick={onClick}
      keyLabel="Country"
      detailsLink={sitePath(site, '/countries')}
      query={query}
      renderIcon={renderIcon}
      color="bg-orange-50"
    />
  )
}

function Regions({query, site, onClick}) {
  function fetchData() {
    return api.get(apiPath(site, '/regions'), query, {limit: 9})
  }

  function renderIcon(region) {
    return <span className="mr-1">{region.country_flag}</span>
  }

  return (
    <ListReport
      fetchData={fetchData}
      filter={{region: 'code', region_name: 'name'}}
      onClick={onClick}
      keyLabel="Region"
      detailsLink={sitePath(site, '/regions')}
      query={query}
      renderIcon={renderIcon}
      color="bg-orange-50"
    />
  )
}

function Cities({query, site}) {
  function fetchData() {
    return api.get(apiPath(site, '/cities'), query, {limit: 9})
  }

  function renderIcon(city) {
    return <span className="mr-1">{city.country_flag}</span>
  }

  return (
    <ListReport
      fetchData={fetchData}
      filter={{city: 'code', city_name: 'name'}}
      keyLabel="City"
      detailsLink={sitePath(site, '/cities')}
      query={query}
      renderIcon={renderIcon}
      color="bg-orange-50"
    />
  )
}


const labelFor = {
	'countries': 'Countries',
	'regions': 'Regions',
	'cities': 'Cities',
}

export default class Locations extends React.Component {
	constructor(props) {
    super(props)
    this.onCountryFilter = this.onCountryFilter.bind(this)
    this.onRegionFilter = this.onRegionFilter.bind(this)
    this.tabKey = `geoTab__${  props.site.domain}`
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || 'map'
    }
  }

  componentDidUpdate(prevProps) {
    const isRemovingFilter = (filterName) => {
      return prevProps.query.filters[filterName] && !this.props.query.filters[filterName]
    }

    if (this.state.mode === 'cities' && isRemovingFilter('region')) {
      this.setMode('regions')()
    }

    if (this.state.mode === 'regions' && isRemovingFilter('country')) {
      this.setMode(this.countriesRestoreMode || 'countries')()
    }
  }

  setMode(mode) {
    return () => {
      storage.setItem(this.tabKey, mode)
      this.setState({mode})
    }
  }

  onCountryFilter(mode) {
    return () => {
      this.countriesRestoreMode = mode
      this.setMode('regions')()
    }
  }

  onRegionFilter() {
    this.setMode('cities')()
  }

	renderContent() {
    switch(this.state.mode) {
		case "cities":
      return <Cities site={this.props.site} query={this.props.query} timer={this.props.timer}/>
		case "regions":
      return <Regions onClick={this.onRegionFilter} site={this.props.site} query={this.props.query} timer={this.props.timer}/>
		case "countries":
      return <Countries onClick={this.onCountryFilter('countries')} site={this.props.site} query={this.props.query} timer={this.props.timer}/>
    case "map":
    default:
      return <CountriesMap onClick={this.onCountryFilter('map')} site={this.props.site} query={this.props.query} timer={this.props.timer}/>
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
          <div className="w-full flex justify-between">
            <h3 className="font-bold dark:text-gray-100">
              {labelFor[this.state.mode] || 'Locations'}
            </h3>
            <ul className="flex font-medium text-xs text-gray-500 dark:text-gray-400 space-x-2">
              { this.renderPill('Map', 'map') }
              { this.renderPill('Countries', 'countries') }
              { this.renderPill('Regions', 'regions') }
              { this.renderPill('Cities', 'cities') }
            </ul>
          </div>
          { this.renderContent() }
        </div>
      </div>
    )
  }
}
