import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Transition from "../../../transition.js";
import FadeIn from '../../fade-in'
import Modal from './modal'
import * as api from '../../api'
import numberFormatter, {durationFormatter} from '../../number-formatter'
import {parseQuery} from '../../query'

const FILTERS = {
  sources: 'Combined source',
  utm_mediums: 'UTM medium',
  utm_sources: 'UTM source',
  utm_campaigns: 'UTM campaign'
}

class SourcesModal extends React.Component {
  constructor(props) {
    super(props)
    this.handleClick = this.handleClick.bind(this)
    const urlparts = this.props.location.pathname.split('/')
    this.state = {
      loading: true,
      selectorOpen: false,
      sources: [],
      query: parseQuery(props.location.search, props.site),
      page: 1,
      filter: urlparts[urlparts.length - 1],
      moreResultsAvailable: false
    }
  }

  loadSources() {
    const {site} = this.props
    const {query, page, sources, filter} = this.state

    if (query.filters.goal) {
      api.get(`/api/stats/${encodeURIComponent(site.domain)}/goal/referrers`, query, {limit: 100, page: page})
        .then((res) => this.setState({loading: false, sources: sources.concat(res), moreResultsAvailable: res.length === 100}))
    } else {
      const include = this.showExtra() ? 'bounce_rate,visit_duration' : null
      api.get(`/api/stats/${encodeURIComponent(site.domain)}/${filter}`, query, {limit: 100, page: page, include: include, show_noref: true})
        .then((res) => this.setState({loading: false, sources: sources.concat(res), moreResultsAvailable: res.length === 100}))
    }
  }

  componentDidMount() {
    this.loadSources()
    document.addEventListener('mousedown', this.handleClick, false);
  }

  componentWillUnmount() {
    document.removeEventListener('mousedown', this.handleClick, false);
  }

  handleClick(e) {
    if (this.dropDownNode && this.dropDownNode.contains(e.target)) return;
    if (!this.state.selectorOpen) return;

    this.setState({selectorOpen: false})
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
    if (this.state.filter === 'sources') query.set('source', source.name)
    if (this.state.filter === 'utm_mediums') query.set('utm_medium', source.name)
    if (this.state.filter === 'utm_sources') query.set('utm_source', source.name)
    if (this.state.filter === 'utm_campaigns') query.set('utm_campaign', source.name)

    return (
      <tr className="text-sm" key={source.name}>
        <td className="p-2">
          <img src={`https://icons.duckduckgo.com/ip3/${source.url}.ico`} className="h-4 w-4 mr-2 align-middle inline" />
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
          <button onClick={this.loadMore.bind(this)} type="button" className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-500 focus:outline-none focus:border-indigo-700 focus:shadow-outline-indigo active:bg-indigo-700 transition ease-in-out duration-150">
            Load more
          </button>
        </div>
      )
    }
  }

  filterURL(filter) {
    return `/${encodeURIComponent(this.props.site.domain)}/${filter}${window.location.search}`
  }

  selectFilter(filter) {
    this.setState({filter, sources: [], loading: true, selectorOpen: false}, this.loadSources.bind(this))
  }

  renderSelector() {
    return (
      <div className="relative inline-block text-left">
        <div>
          <span className="rounded-md shadow-sm">
            <button type="button" onClick={() => this.setState({selectorOpen: true})} className="inline-flex justify-center w-full rounded-md border border-gray-300 px-4 py-2 bg-white text-sm leading-5 font-medium text-gray-700 hover:text-gray-500 focus:outline-none focus:border-blue-300 focus:shadow-outline-blue active:bg-gray-50 active:text-gray-800 transition ease-in-out duration-150">
              { FILTERS[this.state.filter] }
              <svg className="-mr-1 ml-2 h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
            </button>
          </span>
        </div>

        <Transition
          show={this.state.selectorOpen}
          enter="transition ease-out duration-100 transform"
          enterFrom="opacity-0 scale-95"
          enterTo="opacity-100 scale-100"
          leave="transition ease-in duration-75 transform"
          leaveFrom="opacity-100 scale-100"
          leaveTo="opacity-0 scale-95"
        >
          <div className="origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg" ref={node => this.dropDownNode = node}>
            <div className="rounded-md bg-white shadow-xs">
              <div className="py-1">
                <Link to={this.filterURL('sources')} replace className="block px-4 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900 cursor-pointer">Combined source</Link>
                <Link to={this.filterURL('utm_mediums')} replace className="block px-4 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900 cursor-pointer">UTM medium</Link>
                <Link to={this.filterURL('utm_sources')} replace className="block px-4 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900 cursor-pointer">UTM source</Link>
                <Link to={this.filterURL('utm_campaigns')} replace className="block px-4 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900 cursor-pointer">UTM campaign</Link>
              </div>
            </div>
          </div>
        </Transition>
      </div>
    )
  }

  render() {
    return (
      <Modal site={this.props.site}>
        <header className="flex justify-between">
          <h1 className="text-xl font-bold">Top Sources</h1>

          { this.renderSelector() }
        </header>

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
