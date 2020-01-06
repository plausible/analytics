import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import {parseQuery, toHuman} from '../../query'

class ReferrerDrilldownModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      query: parseQuery(props.location.search, props.site)
    }
  }

  componentDidMount() {
    api.get(`/api/stats/${this.props.site.domain}/referrers/${this.props.match.params.referrer}`, this.state.query, {limit: 100, include: 'bounce_rate'})
      .then((res) => this.setState({loading: false, referrers: res.referrers, totalVisitors: res.total_visitors}))
  }

  formatBounceRate(ref) {
    if (ref.bounce_rate) {
      return ref.bounce_rate + '%'
    } else {
      return '-'
    }
  }

  renderReferrer(referrer) {
    return (
      <tr className="text-sm" key={referrer.name}>
        <td className="p-2 truncate">
          <a className="hover:underline" target="_blank" href={'//' + referrer.name}>{ referrer.name }</a>
        </td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(referrer.count)}</td>
        <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(referrer)}</td>
      </tr>
    )
  }

  renderGoalText() {
    if (this.state.query.filters.goal) {
      return (
        <h1 className="text-grey-darker leading-none">completed {this.state.query.filters.goal}</h1>
      )
    }
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading my-32 mx-auto"><div></div></div>
      )
    } else if (this.state.referrers) {
      return (
        <React.Fragment>
          <header className="modal__header">
            <Link to={`/${this.props.site.domain}/referrers${window.location.search}`} className="font-bold text-grey-darker hover:underline">← All referrers</Link>
          </header>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content mt-0">
            <h1 className="mb-0 leading-none">{this.state.totalVisitors} visitors from {this.props.match.params.referrer}<br /> {toHuman(this.state.query)}</h1>
            {this.renderGoalText()}

            <table className="w-full table-striped table-fixed mt-4">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-grey-dark" align="left">Referrer</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Visitors</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Bounce rate</th>
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

export default withRouter(ReferrerDrilldownModal)
