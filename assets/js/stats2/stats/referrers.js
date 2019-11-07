import React from 'react';

import Bar from './bar'
import MoreLink from './more-link'
import numberFormatter from '../number-formatter'

export default class Referrers extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    fetch(`/api/stats/${this.props.site.domain}/referrers${window.location.search}`)
      .then((res) => res.json())
      .then((res) => this.setState({loading: false, referrers: res}))
  }

  renderReferrer(referrer) {
    return (
      <React.Fragment key={referrer.name}>
        <div className="flex items-center justify-between my-2">
          <span className="truncate" style={{maxWidth: '80%'}}>{ referrer.name }</span>
          <span>{numberFormatter(referrer.count)}</span>
        </div>
        <Bar count={referrer.count} all={this.state.referrers} color="blue" />
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
    } else if (this.state.referrers) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4">
          <div className="text-center">
            <h2>Top Referrers</h2>
            <div className="text-grey-darker mt-1">by new visitors</div>
          </div>

          <div className="mt-8">
            { this.state.referrers.map(this.renderReferrer.bind(this)) }
          </div>
          <MoreLink site={this.props.site} list={this.state.referrers} endpoint="referrers" />
        </div>
      )
    }
  }
}
