import React from 'react';
import { Link } from 'react-router-dom'
import FlipMove from 'react-flip-move';
import Datamap from 'datamaps'

import FadeIn from '../../fade-in'
import Bar from '../bar'
import MoreLink from '../more-link'
import numberFormatter from '../../number-formatter'
import * as api from '../../api'
import * as url from '../../url'
import LazyLoader from '../../lazy-loader'

export default class Countries extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
    this.onVisible = this.onVisible.bind(this)
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, countries: null})
      this.fetchCountries()
    }
  }

  onVisible() {
    this.fetchCountries()
    if (this.props.timer) this.props.timer.onTick(this.fetchCountries.bind(this))
  }

  showConversionRate() {
    return !!this.props.query.filters.goal
  }

  fetchCountries() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/countries`, this.props.query)
      .then((res) => this.setState({loading: false, countries: res}))
  }

	label() {
    if (this.showConversionRate()) {
      return 'Conversions'
    }

    return 'Visitors'
  }

  renderCountry(country) {
		const maxWidthDeduction =  this.showConversionRate() ? "10rem" : "5rem"
		const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
    const thisCountry = allCountries.find((c) => c.id === country.name) || {properties: {name: country.name}};
    const countryFullName = thisCountry.properties.name

    return (
      <div
        className="flex items-center justify-between my-1 text-sm"
        key={country.name}
      >
        <Bar
          count={country.count}
          all={this.state.countries}
          bg="bg-orange-50 dark:bg-gray-500 dark:bg-opacity-15"
          maxWidthDeduction={maxWidthDeduction}
        >
          <span
            className="flex px-2 py-1.5 group dark:text-gray-300 relative z-9 break-all"
          >
            <Link
              to={url.setQuery('country', country.name)}
              className="md:truncate block hover:underline"
            >
              {countryFullName}
            </Link>
          </span>
        </Bar>
        <span className="font-medium dark:text-gray-200 w-20 text-right">{numberFormatter(country.count)}</span>
        {this.showConversionRate() && <span className="font-medium dark:text-gray-200 w-20 text-right">{numberFormatter(country.conversion_rate)}%</span>}
      </div>
    )
  }

  renderList() {
    if (this.state.countries && this.state.countries.length > 0) {
      return (
        <>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>Country</span>
            <div className="text-right">
              <span className="inline-block w-20">{ this.label() }</span>
              {this.showConversionRate() && <span className="inline-block w-20">CR</span>}
            </div>
          </div>

          <FlipMove>
            { this.state.countries.map(this.renderCountry.bind(this)) }
          </FlipMove>
        </>
      )
    }

    return <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">No data yet</div>
  }

  render() {
    const { loading } = this.state;
    return (
      <LazyLoader onVisible={this.onVisible} className="flex flex-col flex-grow">
        { loading && <div className="mx-auto loading mt-44"><div></div></div> }
        <FadeIn show={!loading} className="flex-grow">
          { this.renderList() }
        </FadeIn>
        {!loading && <MoreLink site={this.props.site} list={this.state.countries} endpoint="countries" />}
      </LazyLoader>
    )
  }
}
