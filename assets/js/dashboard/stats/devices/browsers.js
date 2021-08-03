import React from 'react';
import { Link } from 'react-router-dom'

import FadeIn from '../../fade-in'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import * as api from '../../api'
import LazyLoader from '../../lazy-loader'

export default class Browsers extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
    this.onVisible = this.onVisible.bind(this)
    this.renderBrowserContent = this.renderBrowserContent.bind(this)
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, browsers: null})
      this.fetchBrowsers()
    }
  }
  
  onVisible() {
    this.fetchBrowsers()
    if (this.props.timer) this.props.timer.onTick(this.fetchBrowsers.bind(this))
  }

  fetchBrowsers() {
    if (this.props.query.filters.browser) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/browser-versions`, this.props.query)
        .then((res) => this.setState({loading: false, browsers: res}))
    } else {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/browsers`, this.props.query)
        .then((res) => this.setState({loading: false, browsers: res}))
    }
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderBrowserContent(browser, query) {
    return (
        <span className="flex px-2 py-1.5 dark:text-gray-300 relative z-9 break-all">
          <Link className="md:truncate block hover:underline" to={{search: query.toString()}}>
            {browser.name}
          </Link>
        </span>
    )
  }

  renderBrowser(browser) {
    const query = new URLSearchParams(window.location.search)
    if (this.props.query.filters.browser) {
      query.set('browser_version', browser.name)
    } else {
      query.set('browser', browser.name)
    }

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={browser.name}>
        <Bar
          count={browser.count}
          all={this.state.browsers}
          bg="bg-green-50 dark:bg-gray-500 dark:bg-opacity-15"
          maxWidthDeduction="6rem"
        >
          {this.renderBrowserContent(browser, query)}
        </Bar>
        <span className="font-medium dark:text-gray-200">
          {numberFormatter(browser.count)}
          <span className="inline-block w-8 text-xs text-right">({browser.percentage}%)</span>
        </span>
      </div>
    )
  }

  renderList() {
    const key = this.props.query.filters.browser ? this.props.query.filters.browser + ' version' : 'Browser'

    if (this.state.browsers && this.state.browsers.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>{ key }</span>
            <span>{ this.label() }</span>
          </div>
          { this.state.browsers && this.state.browsers.map(this.renderBrowser.bind(this)) }
        </React.Fragment>
      )
    } else {
      return <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">No data yet</div>
    }
  }

  render() {
    return (
      <LazyLoader onVisible={this.onVisible} className="flex flex-col flex-grow">
        { this.state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
        <FadeIn show={!this.state.loading} className="flex-grow">
          { this.renderList() }
        </FadeIn>
      </LazyLoader>
    )
  }
}

