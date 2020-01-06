import React from "react";
import { Link, withRouter } from 'react-router-dom'

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
    const include = this.showBounceRate() ? 'bounce_rate' : null

    api.get(`/api/stats/${this.props.site.domain}/referrers`, this.state.query, {limit: 100, include: include})
      .then((res) => this.setState({loading: false, referrers: res}))
  }

  showBounceRate() {
    return !this.state.query.filters.goal
  }

  formatBounceRate(page) {
    if (page.bounce_rate) {
      return page.bounce_rate + '%'
    } else {
      return '-'
    }
  }

  renderReferrer(referrer) {
    return (
      <tr className="text-sm" key={referrer.name}>
        <td className="p-2">
          <Link className="hover:underline truncate" style={{maxWidth: '80%'}} to={`/${this.props.site.domain}/referrers/${referrer.name}${window.location.search}`}>{ referrer.name }</Link>
        </td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(referrer.count)}</td>
        {this.showBounceRate() && <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(referrer)}</td> }
      </tr>
    )
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
            <h1>Top Referrers</h1>
          </header>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content">
            <table className="w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-grey-dark" align="left">Referrer</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Visitors</th>
                  {this.showBounceRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Bounce rate</th>}
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
