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
    this.state = {loading: true}
  }

  componentDidMount() {
    const query = parseQuery(this.props.location.search, this.props.site)

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/countries`, query, {limit: 100})
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

  renderBody() {
    if (this.state.countries) {
      return (
        <React.Fragment>
          <header className="modal__header">
            <h1>Top countries</h1>
          </header>
          <div className="text-grey-darker text-lg ml-1 mt-1">by visitors</div>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content">
            <table className="w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-grey-dark" align="left">Country</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Visitors</th>
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
