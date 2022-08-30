import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter, {durationFormatter} from '../../util/number-formatter'
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
    const detailed = this.showExtra()

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers/${this.props.match.params.referrer}`, this.state.query, {limit: 100, detailed})
      .then((res) => this.setState({loading: false, referrers: res.referrers, totalVisitors: res.total_visitors}))
  }

  showExtra() {
    return this.state.query.period !== 'realtime' && !this.state.query.filters.goal
  }

  showConversionRate() {
    return !!this.state.query.filters.goal
  }

  label() {
    if (this.state.query.period === 'realtime') {
      return 'Current visitors'
    }

    if (this.showConversionRate()) {
      return 'Conversions'
    }

    return 'Visitors'
  }

  formatBounceRate(ref) {
    if (typeof(ref.bounce_rate) === 'number') {
      return ref.bounce_rate + '%'
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

  renderExternalLink(name) {
    if (name !== 'Direct / None') {
      return (
        <a target="_blank" href={'//' + name} rel="noreferrer" className="hidden group-hover:block">
          <svg className="inline h-4 w-4 ml-1 -mt-1 text-gray-600 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
        </a>
      )
    }
  }

  renderReferrerName(referrer) {
    const query = new URLSearchParams(window.location.search)
    query.set('referrer', referrer.name)

    return (
      <span className="flex group items-center">
        <img src={`https://icons.duckduckgo.com/ip3/${referrer.url}.ico`} referrerPolicy="no-referrer" className="h-4 w-4 mr-2 inline" />
        <Link className="block truncate hover:underline dark:text-gray-200" to={{search: query.toString(), pathname: '/' + this.props.site.domain}} title={referrer.name}>
          {referrer.name}
        </Link>
        { this.renderExternalLink(referrer.name) }
      </span>
    )
  }

  renderReferrer(referrer) {
    return (
      <tr className="text-sm dark:text-gray-200" key={referrer.name}>
        <td className="p-2">
          { this.renderReferrerName(referrer) }
        </td>
        {this.showConversionRate() && <td className="p-2 w-32 font-medium" align="right">{numberFormatter(referrer.total_visitors)}</td> }
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(referrer.visitors)}</td>
        {this.showExtra() && <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(referrer)}</td> }
        {this.showExtra() && <td className="p-2 w-32 font-medium" align="right">{this.formatDuration(referrer)}</td> }
        {this.showConversionRate() && <td className="p-2 w-32 font-medium" align="right">{referrer.conversion_rate}%</td> }
      </tr>
    )
  }

  renderGoalText() {
    if (this.state.query.filters.goal) {
      return (
        <h1 className="text-xl font-semibold text-gray-500 dark:text-gray-300 leading-none">completed {this.state.query.filters.goal}</h1>
      )
    }
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading mt-32 mx-auto"><div></div></div>
      )
    } else if (this.state.referrers) {
      return (
        <React.Fragment>
          <h1 className="text-xl font-bold dark:text-gray-100">Referrer drilldown</h1>

          <div className="my-4 border-b border-gray-300 dark:border-gray-500"></div>
          <main className="modal__content mt-0">
            <h1 className="text-xl font-semibold mb-0 leading-none dark:text-gray-200">{this.state.totalVisitors} visitors from {decodeURIComponent(this.props.match.params.referrer)}<br /> {toHuman(this.state.query)}</h1>
            {this.renderGoalText()}

            <table className="w-max overflow-x-auto md:w-full table-striped table-fixed mt-4">
              <thead>
                <tr>
                  <th className="p-2 w-48 md:w-56 lg:w-1/3 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="left">Referrer</th>
                  {this.showConversionRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Total visitors</th>}
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">{this.label()}</th>
                  {this.showExtra() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Bounce rate</th>}
                  {this.showExtra() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Visit duration</th>}
                  {this.showConversionRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">CR</th>}
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
