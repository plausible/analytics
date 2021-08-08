import React from "react";
import { Link, withRouter } from 'react-router-dom'
import Datamap from 'datamaps'
import classNames from 'classnames'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import {parseQuery} from '../../query'

class CountriesModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      query: parseQuery(props.location.search, props.site),
      expanded_country: '',
      expanded_subdivision1: '',
      expanded_subdivision2: ''
    }
  }

  componentDidMount() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/countries`, this.state.query, {limit: 300})
      .then((res) => this.setState({loading: false, countries: res}))
  }

  label() {
    if (this.state.query.period === 'realtime') {
      return 'Current visitors'
    }

    if (this.showConversionRate()) {
      return 'Conversions'
    }

    return 'Visitors'
  }

  showConversionRate() {
    return !!this.state.query.filters.goal
  }

  getSubdivisions1(country_name) {
    this.setState({loading: true})

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/subdivisions1`, this.state.query, {country_name: country_name})
        .then((res) => this.setState({loading: false, subdivisions1: res, expanded_country: country_name}))
  }

  getSubdivisions2(country_name, subdivision1_geoname_id) {
    this.setState({loading: true})

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/subdivisions2`, this.state.query, {country_name: country_name, subdivision1_geoname_id: subdivision1_geoname_id})
        .then((res) => this.setState({loading: false, subdivisions2: res, expanded_subdivision1: country_name + ' / ' + subdivision1_geoname_id}))
  }

  getCities(country_name, subdivision1_geoname_id, subdivision2_geoname_id) {
    this.setState({loading: true})

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/cities`, this.state.query, {country_name: country_name, subdivision1_geoname_id: subdivision1_geoname_id, subdivision2_geoname_id: subdivision2_geoname_id})
        .then((res) => this.setState({loading: false, cities: res, expanded_subdivision2: country_name + ' / ' + subdivision1_geoname_id + ' / ' + subdivision2_geoname_id}))
  }

  renderCityName(country_name, subdivision1_geoname_id, city) {
    return (
        <div className="text-xs block p-2 ml-4" key={subdivision1_geoname_id + ' / ' + city.name + ' Name'}>
        {city.name}
        </div>
  )
  }

  renderCityCount(country_name, subdivision1_geoname_id, city) {
    return (
        <div className="p-2 font-normal" align="block right" key={subdivision1_geoname_id + ' / ' + city.name + ' Count'}>
        {numberFormatter(city.count)} <span className="inline-block text-xs text-right">({city.percentage}%)</span>
        </div>
  )
  }

  renderSubdivision1Name(country_name, subdivision1) {
    return (
        <div className="text-xs block p-2" key={country_name + ' / ' + subdivision1.name + ' Name'}>
        <b onClick={() => this.getSubdivisions2(country_name, subdivision1.name)} className={classNames("mr-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500",
          {"inline-block": this.state.expanded_subdivision1 !== country_name + ' / ' + subdivision1.name},
          {"hidden": this.state.expanded_subdivision1 === country_name + ' / ' + subdivision1.name})}> + </b>
        <b onClick={() => this.setState({expanded_subdivision1: ''})} style={{ display: this.state.expanded_subdivision1 == country_name + ' / ' + subdivision1.name ? "inline-block" : "none" }} className="mr-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500"> - </b>
    {subdivision1.name}
  <div className={classNames({"block": this.state.expanded_subdivision1 === country_name + ' / ' + subdivision1.name},
    {"hidden": this.state.expanded_subdivision1 !== country_name + ' / ' + subdivision1.name})}>
    { this.state.subdivisions2 && this.state.subdivisions2.length > 0 && this.state.expanded_subdivision1 == country_name + ' / ' + subdivision1.name && this.state.subdivisions2.map(this.renderSubdivision2Name.bind(this, country_name, subdivision1.name)) }
  </div>
    </div>
  )
  }

  renderSubdivision1Count(country_name, subdivision1) {
    return (
        <div className={classNames("p-2 font-normal",
          {"block": this.state.expanded_country === country_name},
          {"hidden": this.state.expanded_country !== country_name})} align="block right" key={country_name + ' / ' + subdivision1.name + ' Count'}>
        {numberFormatter(subdivision1.count)} <span className="inline-block text-xs text-right">({subdivision1.percentage}%)</span>
    { this.state.subdivisions2 && this.state.subdivisions2.length > 0 && this.state.expanded_subdivision1 == country_name + ' / ' + subdivision1.name && this.state.subdivisions2.map(this.renderSubdivision2Count.bind(this, country_name, subdivision1.name)) }
  </div>
  )
  }

  renderSubdivision2Name(country_name, subdivision1_name, subdivision2) {
    return (
        <div className="text-xs block p-2" key={country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name + ' Name'}>
        <b onClick={() => this.getCities(country_name, subdivision1_name, subdivision2.name)} className={classNames("mr-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500",
          {"inline-block": this.state.expanded_subdivision2 !== country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name},
          {"hidden": this.state.expanded_subdivision2 === country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name})}> + </b>
        <b onClick={() => this.setState({expanded_subdivision2: ''})} className={classNames("mr-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500",
          {"inline-block": this.state.expanded_subdivision2 === country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name},
          {"hidden": this.state.expanded_subdivision2 !== country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name})}> - </b>
    {subdivision2.name}
  <div className={classNames({"block": this.state.expanded_subdivision2 === country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name},
    {"hidden": this.state.expanded_subdivision2 !== country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name})}>
    { this.state.cities && this.state.cities.length > 0 && this.state.expanded_subdivision2 == country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name && this.state.cities.map(this.renderCityName.bind(this, country_name, subdivision2.name)) }
  </div>
    </div>
  )
  }

  renderSubdivision2Count(country_name, subdivision1_name, subdivision2) {
    return (
        <div className={classNames("p-2 font-normal",
          {"block": this.state.expanded_country === country_name},
          {"hidden": this.state.expanded_country !== country_name})} align="block right" key={country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name + ' Count'}>
        {numberFormatter(subdivision2.count)} <span className="inline-block text-xs text-right">({subdivision2.percentage}%)</span>
    { this.state.cities && this.state.cities.length > 0 && this.state.expanded_subdivision2 == country_name + ' / ' + subdivision1_name + ' / ' + subdivision2.name && this.state.cities.map(this.renderCityCount.bind(this, country_name, subdivision2.name)) }
  </div>
  )
  }

  renderCountry(country) {
    const query = new URLSearchParams(window.location.search)
    query.set('country', country.name)

    const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
    const thisCountry = allCountries.find((c) => c.id === country.name) || {properties: {name: country.name}};
    const countryFullName = thisCountry.properties.name

    return (
      <tr className="text-sm dark:text-gray-200" key={country.name}>
        <td className="p-2">
        <b onClick={() => this.getSubdivisions1(country.name)} className={classNames("mr-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500",
          {"inline-block": this.state.expanded_country !== country.name},
          {"hidden": this.state.expanded_country === country.name})}> + </b>
        <b onClick={() => this.setState({expanded_country: ''})} className={classNames("mr-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500",
          {"inline-block": this.state.expanded_country === country.name},
          {"hidden": this.state.expanded_country !== country.name})}> - </b>
          <Link className="hover:underline" to={{search: query.toString(), pathname: '/' + encodeURIComponent(this.props.site.domain)}}>
            {countryFullName}
          </Link>
          <div className={classNames({"block": this.state.expanded_country === country.name},
            {"hidden": this.state.expanded_country !== country.name})}>
            { this.state.subdivisions1 && this.state.subdivisions1.length > 0 && this.state.expanded_country == country.name && this.state.subdivisions1.map(this.renderSubdivision1Name.bind(this, country.name)) }
          </div>
        </td>
        {this.showConversionRate() && <td className="p-2 w-32 font-medium" align="right">{country.total_visitors}</td> }
        <td className="p-2 w-32 font-medium" align="right">
          {numberFormatter(country.visitors)} {!this.showConversionRate() && <span className="inline-block text-xs w-8 text-right">({country.percentage}%)</span>}
        </td>
        {this.showConversionRate() && <td className="p-2 w-32 font-medium" align="right">{country.conversion_rate}%</td> }
      </tr>
    )
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading mt-32 mx-auto"><div></div></div>
      )
    }

    if (this.state.countries) {
      return (
        <>
          <h1 className="text-xl font-bold dark:text-gray-100">Top countries</h1>

          <div className="my-4 border-b border-gray-300 dark:border-gray-500"></div>
          <main className="modal__content">
            <table className="w-max overflow-x-auto md:w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th
                    className="p-2 w-48 lg:w-1/2 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400"
                    align="left"
                  >
                    Country
                  </th>
                  {this.showConversionRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Total visitors</th>}
                  <th
                    // eslint-disable-next-line max-len
                    className="p-2 w-32 lg:w-1/2 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400"
                    align="right"
                  >
                    {this.label()}
                  </th>
                  {this.showConversionRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">CR</th>}
                </tr>
              </thead>
              <tbody>
                { this.state.countries.map(this.renderCountry.bind(this)) }
              </tbody>
            </table>
          </main>
        </>
      )
    }
  }

  render() {
    return (
      <Modal site={this.props.site} show={!this.state.loading}>
        { this.renderBody() }
      </Modal>
    )
  }
}

export default withRouter(CountriesModal)
