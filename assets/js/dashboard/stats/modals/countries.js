import React from "react";
import { Link, withRouter } from 'react-router-dom'
import Datamap from 'datamaps'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import {parseQuery} from '../../query'

class CountriesModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      query: parseQuery(props.location.search, props.site)
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

  renderCountry(country) {
    const query = new URLSearchParams(window.location.search)
    query.set('country', country.name)

    const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
    const thisCountry = allCountries.find((c) => c.id === country.name) || {properties: {name: country.name}};
    const countryFullName = thisCountry.properties.name

    return (
      <tr className="text-sm dark:text-gray-200" key={country.name}>
        <td className="p-2">
          <Link className="hover:underline" to={{search: query.toString(), pathname: `/${encodeURIComponent(this.props.site.domain)}`}}>
            {countryFullName}
          </Link>
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

    return null
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
