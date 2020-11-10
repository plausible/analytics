import React from 'react';
import { Link } from 'react-router-dom'

import FadeIn from '../../fade-in'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import * as api from '../../api'

export default class Browsers extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchBrowsers()
    if (this.props.timer) this.props.timer.onTick(this.fetchBrowsers.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, browsers: null})
      this.fetchBrowsers()
    }
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

  renderBrowser(browser) {
    const query = new URLSearchParams(window.location.search)
    if (this.props.query.filters.browser) {
      query.set('browser_version', browser.name)
    } else {
      query.set('browser', browser.name)
    }

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={browser.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 6rem)'}}>
          <Bar count={browser.count} all={this.state.browsers} bg="bg-green-50" />
          <span className="flex px-2" style={{marginTop: '-26px'}} >
            <Link className="block truncate hover:underline" to={{search: query.toString()}}>
              {browser.name}
            </Link>
          </span>
        </div>
        <span className="font-medium">{numberFormatter(browser.count)} <span className="inline-block text-xs w-8 text-right">({browser.percentage}%)</span></span>
      </div>
    )
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }


  renderList() {
    const key = this.props.query.filters.browser ? this.props.query.filters.browser + ' version' : 'Browser'

    if (this.state.browsers && this.state.browsers.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>{ key }</span>
            <span>{ this.label() }</span>
          </div>
          { this.state.browsers && this.state.browsers.map(this.renderBrowser.bind(this)) }
        </React.Fragment>
      )
    } else {
      return <div className="text-center mt-44 font-medium text-gray-500">No data yet</div>
    }
  }

  render() {
    return (
      <React.Fragment>
        { this.state.loading && <div className="loading mt-44 mx-auto"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderList() }
        </FadeIn>
      </React.Fragment>
    )
  }
}

