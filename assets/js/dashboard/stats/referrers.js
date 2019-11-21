import React from 'react';
import { Link } from 'react-router-dom'

import Bar from './bar'
import MoreLink from './more-link'
import numberFormatter from '../number-formatter'
import * as api from '../api'

export default class Referrers extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchReferrers()
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, referrers: null})
      this.fetchReferrers()
    }
  }

  fetchReferrers() {
    if (this.props.query.filters.goal) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/goal/referrers`, this.props.query)
        .then((res) => this.setState({loading: false, referrers: res}))
    } else {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers`, this.props.query)
        .then((res) => this.setState({loading: false, referrers: res}))
    }
  }

  renderReferrer(referrer) {
    return (
      <div className="flex items-center justify-between my-1 text-sm" key={referrer.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={referrer.count} all={this.state.referrers} color="blue" />
          <Link className="hover:underline block px-2" style={{marginTop: '-23px'}} to={`/${encodeURIComponent(this.props.site.domain)}/referrers/${referrer.name}${window.location.search}`}>{ referrer.name }</Link>
        </div>
        <span className="font-medium">{numberFormatter(referrer.count)}</span>
      </div>
    )
  }

  renderContent() {
    if (this.state.loading) {
      return <div className="loading my-32 mx-auto"><div></div></div>
    } else {
      return (
        <React.Fragment>

          <div className="flex items-center mt-4 mb-2 justify-between text-grey-dark text-xs font-bold tracking-wide">
            <span>Referrer</span>
            <span>Visitors</span>
          </div>

          { this.state.referrers.map(this.renderReferrer.bind(this)) }
          <MoreLink site={this.props.site} list={this.state.referrers} endpoint="referrers" />
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <div className="stats-item bg-white shadow-xl rounded p-4" style={{height: '436px'}}>
        <h3>Top Referrers</h3>
        { this.renderContent() }
      </div>
    )
  }
}
