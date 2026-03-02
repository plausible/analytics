import React from 'react'

import * as storage from '../../util/storage'
import CountriesMap from './map'

import * as api from '../../api'
import { apiPath } from '../../util/url'
import ListReport from '../reports/list'
import * as metrics from '../reports/metrics'
import {
  hasConversionGoalFilter,
  getFiltersByKeyPrefix
} from '../../util/filters'
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning'
import { citiesRoute, countriesRoute, regionsRoute } from '../../router'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { TabButton, TabWrapper } from '../../components/tabs'
import MoreLink from '../more-link'
import { MoreLinkState } from '../more-link-state'

function Countries({ dashboardState, site, onClick, afterFetchData }) {
  function fetchData() {
    return api.get(apiPath(site, '/countries'), dashboardState, { limit: 9 })
  }

  function renderIcon(country) {
    return <span className="mr-2">{country.flag}</span>
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'country',
      filter: ['is', 'country', [listItem['code']]],
      labels: { [listItem['code']]: listItem['name'] }
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      !hasConversionGoalFilter(dashboardState) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      onClick={onClick}
      keyLabel="Country"
      metrics={chooseMetrics()}
      renderIcon={renderIcon}
      color="bg-orange-50 group-hover/row:bg-orange-100"
    />
  )
}

function Regions({ dashboardState, site, onClick, afterFetchData }) {
  function fetchData() {
    return api.get(apiPath(site, '/regions'), dashboardState, { limit: 9 })
  }

  function renderIcon(region) {
    return <span className="mr-2">{region.country_flag}</span>
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'region',
      filter: ['is', 'region', [listItem['code']]],
      labels: { [listItem['code']]: listItem['name'] }
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      !hasConversionGoalFilter(dashboardState) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      onClick={onClick}
      keyLabel="Region"
      metrics={chooseMetrics()}
      renderIcon={renderIcon}
      color="bg-orange-50 group-hover/row:bg-orange-100"
    />
  )
}

function Cities({ dashboardState, site, afterFetchData }) {
  function fetchData() {
    return api.get(apiPath(site, '/cities'), dashboardState, { limit: 9 })
  }

  function renderIcon(city) {
    return <span className="mr-2">{city.country_flag}</span>
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'city',
      filter: ['is', 'city', [listItem['code']]],
      labels: { [listItem['code']]: listItem['name'] }
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      !hasConversionGoalFilter(dashboardState) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="City"
      metrics={chooseMetrics()}
      renderIcon={renderIcon}
      color="bg-orange-50 group-hover/row:bg-orange-100"
    />
  )
}

class Locations extends React.Component {
  constructor(props) {
    super(props)
    this.onCountryFilter = this.onCountryFilter.bind(this)
    this.onRegionFilter = this.onRegionFilter.bind(this)
    this.afterFetchData = this.afterFetchData.bind(this)
    this.tabKey = `geoTab__${props.site.domain}`
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || 'map',
      loading: true,
      skipImportedReason: null,
      moreLinkState: MoreLinkState.LOADING
    }
  }

  componentDidUpdate(prevProps, prevState) {
    const isRemovingFilter = (filterName) => {
      return (
        getFiltersByKeyPrefix(prevProps.dashboardState, filterName).length >
          0 &&
        getFiltersByKeyPrefix(this.props.dashboardState, filterName).length == 0
      )
    }

    if (this.state.mode === 'cities' && isRemovingFilter('region')) {
      this.setMode('regions')()
    }

    if (this.state.mode === 'regions' && isRemovingFilter('country')) {
      this.setMode(this.countriesRestoreMode || 'countries')()
    }

    if (
      this.props.dashboardState !== prevProps.dashboardState ||
      this.state.mode !== prevState.mode
    ) {
      this.setState({ loading: true, moreLinkState: MoreLinkState.LOADING })
    }
  }

  setMode(mode) {
    return () => {
      storage.setItem(this.tabKey, mode)
      this.setState({ mode })
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

  afterFetchData(apiResponse) {
    let newMoreLinkState

    if (apiResponse.results && apiResponse.results.length > 0) {
      newMoreLinkState = MoreLinkState.READY
    } else {
      newMoreLinkState = MoreLinkState.HIDDEN
    }
    this.setState({
      loading: false,
      moreLinkState: newMoreLinkState,
      skipImportedReason: apiResponse.skip_imported_reason
    })
  }

  renderContent() {
    switch (this.state.mode) {
      case 'cities':
        return (
          <Cities
            site={this.props.site}
            dashboardState={this.props.dashboardState}
            afterFetchData={this.afterFetchData}
          />
        )
      case 'regions':
        return (
          <Regions
            onClick={this.onRegionFilter}
            site={this.props.site}
            dashboardState={this.props.dashboardState}
            afterFetchData={this.afterFetchData}
          />
        )
      case 'countries':
        return (
          <Countries
            onClick={this.onCountryFilter('countries')}
            site={this.props.site}
            dashboardState={this.props.dashboardState}
            afterFetchData={this.afterFetchData}
          />
        )
      case 'map':
      default:
        return (
          <CountriesMap
            onCountrySelect={this.onCountryFilter('map')}
            afterFetchData={this.afterFetchData}
          />
        )
    }
  }

  getMoreLinkProps() {
    let path

    if (this.state.mode === 'regions') {
      path = regionsRoute.path
    } else if (this.state.mode === 'cities') {
      path = citiesRoute.path
    } else {
      path = countriesRoute.path
    }

    return { path: path, search: (search) => search }
  }

  render() {
    return (
      <ReportLayout
        className={this.state.mode === 'map' ? '' : 'overflow-x-hidden'}
      >
        <ReportHeader>
          <div className="flex gap-x-3">
            <TabWrapper>
              {[
                { label: 'Map', value: 'map' },
                { label: 'Countries', value: 'countries' },
                { label: 'Regions', value: 'regions' },
                { label: 'Cities', value: 'cities' }
              ].map(({ value, label }) => (
                <TabButton
                  key={value}
                  onClick={this.setMode(value)}
                  active={this.state.mode === value}
                >
                  {label}
                </TabButton>
              ))}
            </TabWrapper>
            <ImportedQueryUnsupportedWarning
              loading={this.state.loading}
              skipImportedReason={this.state.skipImportedReason}
            />
          </div>
          <MoreLink
            linkProps={this.getMoreLinkProps()}
            state={this.state.moreLinkState}
          />
        </ReportHeader>
        {this.renderContent()}
      </ReportLayout>
    )
  }
}

function LocationsWithContext() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  return <Locations site={site} dashboardState={dashboardState} />
}
export default LocationsWithContext
