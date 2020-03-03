import React from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import {parseQuery} from '../../query'

class PagesModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      query: parseQuery(props.location.search, props.site)
    }
  }

  componentDidMount() {
    const include = this.showBounceRate() ? 'bounce_rate' : null

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/pages`, this.state.query, {limit: 100, include: include})
      .then((res) => this.setState({loading: false, pages: res}))
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

  renderPage(page) {
    return (
      <tr className="text-sm" key={page.name}>
        <td className="p-2 truncate">{page.name}</td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(page.count)}</td>
        {this.showBounceRate() && <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(page)}</td> }
      </tr>
    )
  }

  renderBody() {
    if (this.state.pages) {
      return (
        <React.Fragment>
          <header className="modal__header">
            <h1>Top pages</h1>
          </header>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content">
            <table className="w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-grey-dark" align="left">Page url</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Pageviews</th>
                  {this.showBounceRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Bounce rate</th>}
                </tr>
              </thead>
              <tbody>
                { this.state.pages.map(this.renderPage.bind(this)) }
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

export default withRouter(PagesModal)
