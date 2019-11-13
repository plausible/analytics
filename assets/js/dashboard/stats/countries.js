import React from 'react';

import Bar from './bar'
import MoreLink from './more-link'
import * as api from '../api'

export default class Countries extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true
    }
  }

  componentDidMount() {
    this.fetchCountries()
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, countries: null})
      this.fetchCountries()
    }
  }

  fetchCountries() {
    api.get(`/api/stats/${this.props.site.domain}/countries`, this.props.query)
      .then((res) => this.setState({loading: false, countries: res}))
  }

  renderCountry(page) {
    return (
      <React.Fragment key={page.name}>
        <div className="flex items-center justify-between my-2">
          <span className="truncate" style={{maxWidth: '80%'}}>{page.name}</span>
          <span>{page.percentage}%</span>
        </div>
        <Bar count={page.count} all={this.state.countries} color="indigo" />
      </React.Fragment>
    )
  }

  render() {
    if (this.state.loading) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4">
          <div className="loading my-32 mx-auto"><div></div></div>
        </div>
      )
    } else if (this.state.countries) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4">
          <div className="text-center">
            <h2>Top Countries</h2>
            <div className="text-grey-darker mt-1">by visitors</div>
          </div>

          <div className="mt-8">
            { this.state.countries.map(this.renderCountry.bind(this)) }
          </div>
          <MoreLink site={this.props.site} list={this.state.countries} endpoint="countries" />
        </div>
      )
    }
  }
}
