import React from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
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
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/countries`, this.state.query, {limit: 100})
      .then((res) => this.setState({loading: false, countries: res}))
  }

  renderCountry(country) {
    return (
      <tr className="text-sm" key={country.name}>
        <td className="p-2">{country.full_country_name}</td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(country.percentage)}%</td>
      </tr>
    )
  }

  label() {
    return this.state.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading mt-32 mx-auto"><div></div></div>
      )
    } else if (this.state.countries) {
      return (
        <React.Fragment>
          <h1 className="text-xl font-bold">Top countries</h1>

          <div className="my-4 border-b border-gray-300"></div>
          <main className="modal__content">
            <table className="w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-gray-500" align="left">Country</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">{this.label()}</th>
                </tr>
              </thead>
              <tbody>
                { this.state.countries.map(this.renderCountry.bind(this)) }
              </tbody>
            </table>
          </main>
        </React.Fragment>
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
