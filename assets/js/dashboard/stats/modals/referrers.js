import React from "react";
import { Link, withRouter } from 'react-router-dom'

import FadeIn from '../../fade-in'
import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import {parseQuery} from '../../query'

class ReferrersModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      query: parseQuery(props.location.search, props.site)
    }
  }

  componentDidMount() {
    if (this.state.query.filters.goal) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/goal/referrers`, this.state.query, {limit: 100})
        .then((res) => this.setState({loading: false, referrers: res}))
    } else {
      const include = this.showBounceRate() ? 'bounce_rate' : null

      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers`, this.state.query, {limit: 100, include: include})
        .then((res) => this.setState({loading: false, referrers: res}))
    }
  }

  showBounceRate() {
    return !this.state.query.filters.goal
  }

  formatBounceRate(page) {
    if (typeof(page.bounce_rate) === 'number') {
      return page.bounce_rate + '%'
    } else {
      return '-'
    }
  }

  renderReferrer(referrer) {
    return (
      <tr className="text-sm" key={referrer.name}>
        <td className="p-2">
          <img src={`https://icons.duckduckgo.com/ip3/${referrer.url}.ico`} className="h-4 w-4 mr-2 align-middle inline" />
          <Link className="hover:underline truncate" style={{maxWidth: '80%'}} to={`/${encodeURIComponent(this.props.site.domain)}/referrers/${referrer.name}${window.location.search}`}>{ referrer.name }</Link>
        </td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(referrer.count)}</td>
        {this.showBounceRate() && <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(referrer)}</td> }
      </tr>
    )
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading mt-32 mx-auto"><div></div></div>
      )
    } else if (this.state.referrers) {
      return (
        <React.Fragment>
          <h1 className="text-xl font-bold">Top Referrers</h1>

          <div className="my-4 border-b border-gray-300"></div>
          <main className="modal__content">
            <table className="w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-gray-500" align="left">Referrer</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Visitors</th>
                  {this.showBounceRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Bounce rate</th>}
                </tr>
              </thead>
              <tbody>
                { this.state.referrers.map(this.renderReferrer.bind(this)) }
              </tbody>
            </table>
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

export default withRouter(ReferrersModal)
