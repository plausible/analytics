import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Transition from "../../../transition.js";
import FadeIn from '../../fade-in'
import Modal from './modal'
import * as api from '../../api'
import numberFormatter, {durationFormatter} from '../../number-formatter'
import {parseQuery} from '../../query'

const TITLES = {
  sources: 'Top sources',
  utm_mediums: 'Top UTM mediums',
  utm_sources: 'Top UTM sources',
  utm_campaigns: 'Top UTM campaigns'
}

class SourcesModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      sources: [],
      query: parseQuery(props.location.search, props.site),
      page: 1,
      moreResultsAvailable: false
    }
  }

  loadSources() {
    const {site} = this.props
    const {query, page, sources} = this.state

    const include = this.showExtra() ? 'bounce_rate,visit_duration' : null
    api.get(`/api/stats/${encodeURIComponent(site.domain)}/${this.currentFilter()}`, query, {limit: 100, page: page, include: include, show_noref: true})
      .then((res) => this.setState({loading: false, sources: sources.concat(res), moreResultsAvailable: res.length === 100}))
  }

  componentDidMount() {
    this.loadSources()
  }

  componentDidUpdate(prevProps) {
    if (this.props.location.pathname !== prevProps.location.pathname) {
      this.setState({sources: [], loading: true}, this.loadSources.bind(this))
    }
  }

  currentFilter() {
    const urlparts = this.props.location.pathname.split('/')
    return urlparts[urlparts.length - 1]
  }

  showExtra() {
    return this.state.query.period !== 'realtime' && !this.state.query.filters.goal
  }

  loadMore() {
    this.setState({loading: true, page: this.state.page + 1}, this.loadSources.bind(this))
  }

  formatBounceRate(page) {
    if (typeof(page.bounce_rate) === 'number') {
      return page.bounce_rate + '%'
    } else {
      return '-'
    }
  }

  formatDuration(source) {
    if (typeof(source.visit_duration) === 'number') {
      return durationFormatter(source.visit_duration)
    } else {
      return '-'
    }
  }

  renderSource(source) {
    const query = new URLSearchParams(window.location.search)
    const filter = this.currentFilter()
    if (filter === 'sources') query.set('source', source.name)
    if (filter === 'utm_mediums') query.set('utm_medium', source.name)
    if (filter === 'utm_sources') query.set('utm_source', source.name)
    if (filter === 'utm_campaigns') query.set('utm_campaign', source.name)

    return (
      <tr className="text-sm" key={source.name}>
        <td className="p-2">
          <img src={`https://icons.duckduckgo.com/ip3/${source.url}.ico`} referrerPolicy="no-referrer" className="h-4 w-4 mr-2 align-middle inline" />
          <Link className="hover:underline" to={{search: query.toString(), pathname: '/' + encodeURIComponent(this.props.site.domain)}}>{ source.name }</Link>
        </td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(source.count)}</td>
        {this.showExtra() && <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(source)}</td> }
        {this.showExtra() && <td className="p-2 w-32 font-medium" align="right">{this.formatDuration(source)}</td> }
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
          <button onClick={this.loadMore.bind(this)} type="button" className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-500 focus:outline-none focus:border-indigo-700 focus:ring active:bg-indigo-700 transition ease-in-out duration-150">
            Load more
          </button>
        </div>
      )
    }
  }

  title() {
    return TITLES[this.currentFilter()]
  }

  render() {
    return (
      <Modal site={this.props.site}>
        <h1 className="text-xl font-bold">{this.title()}</h1>

        <div className="my-4 border-b border-gray-300"></div>

        <main className="modal__content">
          <table className="w-full table-striped table-fixed">
            <thead>
              <tr>
                <th className="p-2 text-xs tracking-wide font-bold text-gray-500" align="left">Source</th>
                <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">{this.label()}</th>
                {this.showExtra() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Bounce rate</th>}
                {this.showExtra() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Visit duration</th>}
              </tr>
            </thead>
            <tbody>
              { this.state.sources.map(this.renderSource.bind(this)) }
            </tbody>
          </table>
        </main>

        { this.renderLoading() }
      </Modal>
    )
  }
}

export default withRouter(SourcesModal)
