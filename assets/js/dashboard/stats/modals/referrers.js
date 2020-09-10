import React from "react";
import { Link, withRouter } from 'react-router-dom'

import FadeIn from '../../fade-in'
import Modal from './modal'
import * as api from '../../api'
import numberFormatter, {durationFormatter} from '../../number-formatter'
import {parseQuery} from '../../query'

class ReferrersModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      referrers: [],
      query: parseQuery(props.location.search, props.site),
      page: 1,
      moreResultsAvailable: false
    }
  }

  loadReferrers() {
    const {query, page, referrers} = this.state

    if (query.filters.goal) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/goal/referrers`, query, {limit: 100, page: page})
        .then((res) => this.setState({loading: false, referrers: referrers.concat(res), moreResultsAvailable: res.length === 100}))
    } else {
      const include = this.showExtra() ? 'bounce_rate,visit_duration' : null

      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers`, query, {limit: 100, page: page, include: include, show_noref: true})
        .then((res) => this.setState({loading: false, referrers: referrers.concat(res), moreResultsAvailable: res.length === 100}))
    }
  }

  componentDidMount() {
    this.loadReferrers()
  }

  showExtra() {
    return this.state.query.period !== 'realtime' && !this.state.query.filters.goal
  }

  loadMore() {
    this.setState({loading: true, page: this.state.page + 1}, this.loadReferrers.bind(this))
  }

  formatBounceRate(page) {
    if (typeof(page.bounce_rate) === 'number') {
      return page.bounce_rate + '%'
    } else {
      return '-'
    }
  }

  formatDuration(referrer) {
    if (typeof(referrer.visit_duration) === 'number') {
      return durationFormatter(referrer.visit_duration)
    } else {
      return '-'
    }
  }

  renderReferrer(referrer) {
    const query = new URLSearchParams(window.location.search)
    query.set('source', referrer.name)

    return (
      <tr className="text-sm" key={referrer.name}>
        <td className="p-2">
          <img src={`https://icons.duckduckgo.com/ip3/${referrer.url}.ico`} className="h-4 w-4 mr-2 align-middle inline" />
          <Link className="hover:underline truncate" style={{maxWidth: '80%'}} to={{search: query.toString(), pathname: '/' + encodeURIComponent(this.props.site.domain)}}>{ referrer.name }</Link>
        </td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(referrer.count)}</td>
        {this.showExtra() && <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(referrer)}</td> }
        {this.showExtra() && <td className="p-2 w-32 font-medium" align="right">{this.formatDuration(referrer)}</td> }
      </tr>
    )
  }

  label() {
    return this.state.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderLoading() {
    if (this.state.loading) {
      return <div className="loading my-16 mx-auto"><div></div></div>
    } else if (this.state.moreResultsAvailable) {
      return (
        <div className="w-full text-center my-4">
          <button onClick={this.loadMore.bind(this)} type="button" className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-500 focus:outline-none focus:border-indigo-700 focus:shadow-outline-indigo active:bg-indigo-700 transition ease-in-out duration-150">
            Load more
          </button>
        </div>
      )
    }
  }

  render() {
    return (
      <Modal site={this.props.site}>
        <h1 className="text-xl font-bold">Top Sources</h1>

        <div className="my-4 border-b border-gray-300"></div>

        <main className="modal__content">
          <table className="w-full table-striped table-fixed">
            <thead>
              <tr>
                <th className="p-2 text-xs tracking-wide font-bold text-gray-500" align="left">Referrer</th>
                <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">{this.label()}</th>
                {this.showExtra() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Bounce rate</th>}
                {this.showExtra() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Visit duration</th>}
              </tr>
            </thead>
            <tbody>
              { this.state.referrers.map(this.renderReferrer.bind(this)) }
            </tbody>
          </table>
        </main>

        { this.renderLoading() }
      </Modal>
    )
  }
}

export default withRouter(ReferrersModal)
