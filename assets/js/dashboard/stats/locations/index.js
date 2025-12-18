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
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { TabButton, TabWrapper } from '../../components/tabs'
import MoreLink from '../more-link'

function Countries({ query, site, onClick, afterFetchData, onListUpdate }) {
  function fetchData() {
    return api.get(apiPath(site, '/countries'), query, { limit: 9 })
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
      !hasConversionGoalFilter(query) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
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
      detailsLinkProps={{
        path: countriesRoute.path,
        search: (search) => search
      }}
      renderIcon={renderIcon}
      color="bg-orange-50 group-hover/row:bg-orange-100"
      onListUpdate={onListUpdate}
    />
  )
}

function Regions({ query, site, onClick, afterFetchData, onListUpdate }) {
  function fetchData() {
    return api.get(apiPath(site, '/regions'), query, { limit: 9 })
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
      !hasConversionGoalFilter(query) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
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
      detailsLinkProps={{ path: regionsRoute.path, search: (search) => search }}
      renderIcon={renderIcon}
      color="bg-orange-50 group-hover/row:bg-orange-100"
      onListUpdate={onListUpdate}
    />
  )
}

function Cities({ query, site, afterFetchData, onListUpdate }) {
  function fetchData() {
    return api.get(apiPath(site, '/cities'), query, { limit: 9 })
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
      !hasConversionGoalFilter(query) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="City"
      metrics={chooseMetrics()}
      detailsLinkProps={{ path: citiesRoute.path, search: (search) => search }}
      renderIcon={renderIcon}
      color="bg-orange-50 group-hover/row:bg-orange-100"
      onListUpdate={onListUpdate}
    />
  )
}

class Locations extends React.Component {
  constructor(props) {
    super(props)
    this.onCountryFilter = this.onCountryFilter.bind(this)
    this.onRegionFilter = this.onRegionFilter.bind(this)
    this.afterFetchData = this.afterFetchData.bind(this)
    this.onListUpdate = this.onListUpdate.bind(this)
    this.onMapDataUpdate = this.onMapDataUpdate.bind(this)
    this.tabKey = `geoTab__${props.site.domain}`
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || 'map',
      loading: true,
      skipImportedReason: null,
      listData: null,
      linkProps: null,
      listLoading: true,
      mapData: null,
      mapLoading: true
    }
  }

  componentDidUpdate(prevProps, prevState) {
    const isRemovingFilter = (filterName) => {
      return (
        getFiltersByKeyPrefix(prevProps.query, filterName).length > 0 &&
        getFiltersByKeyPrefix(this.props.query, filterName).length == 0
      )
    }

    if (this.state.mode === 'cities' && isRemovingFilter('region')) {
      this.setMode('regions')()
    }

    if (this.state.mode === 'regions' && isRemovingFilter('country')) {
      this.setMode(this.countriesRestoreMode || 'countries')()
    }

    if (
      this.props.query !== prevProps.query ||
      this.state.mode !== prevState.mode
    ) {
      this.setState({ loading: true })
    }
  }

  setMode(mode) {
    return () => {
      storage.setItem(this.tabKey, mode)
      this.setState({
        mode,
        listData: null,
        linkProps: null,
        listLoading: true,
        mapData: null,
        mapLoading: true
      })
    }
  }

  onListUpdate(list, linkProps, loading) {
    this.setState({ listData: list, linkProps, listLoading: loading })
  }

  onMapDataUpdate(data, loading) {
    this.setState({ mapData: data, mapLoading: loading })
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
    this.setState({
      loading: false,
      skipImportedReason: apiResponse.skip_imported_reason
    })
  }

  renderContent() {
    switch (this.state.mode) {
      case 'cities':
        return (
          <Cities
            site={this.props.site}
            query={this.props.query}
            afterFetchData={this.afterFetchData}
            onListUpdate={this.onListUpdate}
          />
        )
      case 'regions':
        return (
          <Regions
            onClick={this.onRegionFilter}
            site={this.props.site}
            query={this.props.query}
            afterFetchData={this.afterFetchData}
            onListUpdate={this.onListUpdate}
          />
        )
      case 'countries':
        return (
          <Countries
            onClick={this.onCountryFilter('countries')}
            site={this.props.site}
            query={this.props.query}
            afterFetchData={this.afterFetchData}
            onListUpdate={this.onListUpdate}
          />
        )
      case 'map':
      default:
        return (
          <CountriesMap
            onCountrySelect={this.onCountryFilter('map')}
            afterFetchData={this.afterFetchData}
            onDataUpdate={this.onMapDataUpdate}
          />
        )
    }
  }

  getMoreLink() {
    if (this.state.mode === 'map') {
      const data = this.state.mapData?.results ?? []
      return (
        <MoreLink
          list={data}
          linkProps={{
            path: countriesRoute.path,
            search: (search) => search
          }}
          loading={this.state.mapLoading}
          className=""
          onClick={undefined}
        />
      )
    } else {
      return (
        <MoreLink
          list={this.state.listData}
          linkProps={this.state.linkProps}
          loading={this.state.listLoading}
          className=""
          onClick={undefined}
        />
      )
    }
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
          {this.getMoreLink()}
        </ReportHeader>
        {this.renderContent()}
      </ReportLayout>
    )
  }
}

function LocationsWithContext() {
  const { query } = useQueryContext()
  const site = useSiteContext()
  return <Locations site={site} query={query} />
}
export default LocationsWithContext
