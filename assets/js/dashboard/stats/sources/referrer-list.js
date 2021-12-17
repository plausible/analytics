import React from 'react';
import { Link } from 'react-router-dom'
import FlipMove from 'react-flip-move';

import FadeIn from '../../fade-in'
import Bar from '../bar'
import MoreLink from '../more-link'
import numberFormatter from '../../util/number-formatter'
import * as api from '../../api'
import LazyLoader from '../../components/lazy-loader'

function LinkOption(props) {
  if (props.disabled) {
    return <span {...props}>{props.children}</span>
  } else {
    props = Object.assign({}, props, {className: props.className + ' hover:underline'})
    return <Link {...props}>{props.children}</Link>
  }
}

export default class Referrers extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
    this.onVisible = this.onVisible.bind(this)
  }

  onVisible() {
    this.fetchReferrers()
    if (this.props.timer) this.props.timer.onTick(this.fetchReferrers.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, referrers: null})
      this.fetchReferrers()
    }
  }

  showNoRef() {
    return this.props.query.period === 'realtime'
  }

  showConversionRate() {
    return !!this.props.query.filters.goal
  }

  fetchReferrers() {
    if (this.props.query.filters.source) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers/${encodeURIComponent(this.props.query.filters.source)}`, this.props.query, {show_noref: this.showNoRef()})
        .then((res) => res.search_terms || res.referrers)
        .then((referrers) => this.setState({loading: false, referrers: referrers}))
    } else if (this.props.query.filters.goal) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/goal/referrers`, this.props.query)
        .then((res) => this.setState({loading: false, referrers: res}))
    } else {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers`, this.props.query, {show_noref: this.showNoRef()})
        .then((res) => this.setState({loading: false, referrers: res}))
    }
  }

  renderExternalLink(referrer) {
    if (this.props.query.filters.source && this.props.query.filters.source !== 'Google' && referrer.name !== 'Direct / None') {
      return (
        <a target="_blank" href={'//' + referrer.name} rel="noreferrer" className="hidden group-hover:block">
          <svg className="inline w-4 h-4 ml-1 -mt-1 text-gray-600 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
        </a>
      )
    }
    return null
  }

  renderReferrer(referrer) {
    const maxWidthDeduction =  this.showConversionRate() ? "10rem" : "5rem"
    const query = new URLSearchParams(window.location.search)
    query.set('referrer', referrer.name)

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={referrer.name}>
        <Bar
          count={referrer.visitors}
          all={this.state.referrers}
          bg="bg-blue-50 dark:bg-gray-500 dark:bg-opacity-15"
          maxWidthDeduction={maxWidthDeduction}
        >
          <span className="flex px-2 py-1.5 z-9 relative break-all group">
            <LinkOption
              className="block md:truncate dark:text-gray-300"
              to={{search: query.toString()}}
              disabled={referrer.name === 'Direct / None'}
            >
              <img
                src={`/favicon/sources/${encodeURIComponent(referrer.name)}`}
                referrerPolicy="no-referrer"
                className="inline w-4 h-4 mr-2 -mt-px align-middle"
              />
              { referrer.name }
            </LinkOption>
            { this.renderExternalLink(referrer) }
          </span>
        </Bar>
        <span className="font-medium dark:text-gray-200">{numberFormatter(referrer.visitors)}</span>
        {this.showConversionRate() && <span className="font-medium dark:text-gray-200 w-20 text-right">{referrer.conversion_rate}%</span>}
      </div>
    )
  }

  label() {
    if (this.props.query.period === 'realtime') {
      return 'Current visitors'
    }

    if (this.showConversionRate()) {
      return 'Conversions'
    }

    return 'Visitors'
  }

  renderList() {
    if (this.state.referrers.length > 0) {
      return (
        <div className="flex flex-col flex-grow">
          <div
            className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500"
          >
            <span>Referrer</span>

            <div className="text-right">
              <span className="inline-block w-20">{this.label()}</span>
              {this.showConversionRate() && <span className="inline-block w-20">CR</span>}
            </div>
          </div>

          <FlipMove className="flex-grow">
            {this.state.referrers.map(this.renderReferrer.bind(this))}
          </FlipMove>
        </div>
      )
    }
    return (
      <div
        className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400"
      >
        No data yet
      </div>
    )
  }

  renderContent() {
    if (this.state.referrers) {
      return (
        <React.Fragment>
          { this.renderList() }
          <MoreLink site={this.props.site} list={this.state.referrers} endpoint={`referrers/${this.props.query.filters.source}`} />
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <div
        className="relative p-4 bg-white rounded shadow-xl stats-item flex flex-col dark:bg-gray-825 mt-6 w-full"
      >
        <LazyLoader onVisible={this.onVisible} className="flex flex-col flex-grow">
          <h3 className="font-bold dark:text-gray-100">Top Referrers</h3>
          { this.state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
          <FadeIn show={!this.state.loading}>
            { this.renderContent() }
          </FadeIn>
        </LazyLoader>
      </div>
    )
  }
}
