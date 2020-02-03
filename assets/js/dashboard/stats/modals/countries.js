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
      <React.Fragment key={country.name}>
        <div className="flex items-center justify-between my-2">
          <span>{country.name}</span>
          <span tooltip={`${country.count} visitors`}>{country.percentage}%</span>
        </div>
        <Bar count={country.count} all={this.state.countries} color="indigo" />
      </React.Fragment>
    )
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading my-32 mx-auto"><div></div></div>
      )
    } else if (this.state.countries) {
      return (
        <React.Fragment>
          <header className="modal__header">
            <h1>Top countries</h1>
          </header>
          <div className="text-grey-darker text-lg ml-1 mt-1">by visitors</div>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content">
            <div className="mt-8">
              { this.state.countries.map(this.renderCountry.bind(this)) }
            </div>
          </main>
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <Modal site={this.props.site}>
        { this.renderBody() }
      </Modal>
    )
  }
}

export default withRouter(CountriesModal)
