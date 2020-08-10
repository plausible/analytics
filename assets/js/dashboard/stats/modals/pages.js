import React from "react";
import { Link } from 'react-router-dom'
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

    const {filters} = this.state.query
    if (filters.source || filters.referrer) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/entry-pages`, this.state.query, {limit: 100, include: include})
        .then((res) => this.setState({loading: false, pages: res}))
    } else {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/pages`, this.state.query, {limit: 100, include: include})
        .then((res) => this.setState({loading: false, pages: res}))
    }
  }

  showBounceRate() {
    return this.state.query.period !== 'realtime' && !this.state.query.filters.goal
  }

  showPageviews() {
    const {filters} = this.state.query
    return this.state.query.period !== 'realtime' && !(filters.goal || filters.source || filters.referrer)
  }

  formatBounceRate(page) {
    if (typeof(page.bounce_rate) === 'number') {
      return page.bounce_rate + '%'
    } else {
      return '-'
    }
  }

  renderPage(page) {
    const query = new URLSearchParams(window.location.search)
    query.set('page', page.name)

    return (
      <tr className="text-sm" key={page.name}>
        <td className="p-2 truncate">
          <Link to={{pathname: `/${encodeURIComponent(this.props.site.domain)}`, search: query.toString()}} className="hover:underline">{page.name}</Link>
        </td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(page.count)}</td>
        {this.showPageviews() && <td className="p-2 w-32 font-medium" align="right">{numberFormatter(page.pageviews)}</td> }
        {this.showBounceRate() && <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(page)}</td> }
      </tr>
    )
  }

  label() {
    return this.state.query.period === 'realtime' ? 'Active visitors' : 'Visitors'
  }

  title() {
    const {filters} = this.state.query
    return (filters.source || filters.referrer) ? 'Entry Pages' : 'Top Pages'
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading mt-32 mx-auto"><div></div></div>
      )
    } else if (this.state.pages) {
      return (
        <React.Fragment>
          <h1 className="text-xl font-bold">{this.title()}</h1>

          <div className="my-4 border-b border-gray-300"></div>
          <main className="modal__content">
            <table className="w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-gray-500" align="left">Page url</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">{ this.label() }</th>
                  {this.showPageviews() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Pageviews</th>}
                  {this.showBounceRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Bounce rate</th>}
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
      <Modal site={this.props.site}>
        { this.renderBody() }
      </Modal>
    )
  }
}

export default withRouter(PagesModal)
