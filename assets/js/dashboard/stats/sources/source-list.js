import React from 'react';
import { Link } from 'react-router-dom'
import FlipMove from 'react-flip-move';

import * as storage from '../../storage'
import FadeIn from '../../fade-in'
import Bar from '../bar'
import MoreLink from '../more-link'
import numberFormatter from '../../number-formatter'
import * as api from '../../api'
import LazyLoader from '../../lazy-loader'

class AllSources extends React.Component {
  constructor(props) {
    super(props)
    this.onVisible = this.onVisible.bind(this)
    this.state = {loading: true}
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

  fetchReferrers() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/sources`, this.props.query, {show_noref: this.showNoRef()})
      .then((res) => this.setState({loading: false, referrers: res}))
  }

  renderReferrer(referrer) {
    const query = new URLSearchParams(window.location.search)
    query.set('source', referrer.name)

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={referrer.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={referrer.count} all={this.state.referrers} bg="bg-blue-50 dark:bg-gray-500 dark:bg-opacity-15" />
          <span className="flex px-2 dark:text-gray-300" style={{marginTop: '-26px'}} >
            <Link className="block truncate hover:underline" to={{search: query.toString()}}>
              <img src={`https://icons.duckduckgo.com/ip3/${referrer.url}.ico`} referrerPolicy="no-referrer" className="inline w-4 h-4 mr-2 -mt-px align-middle" />
              { referrer.name }
            </Link>
          </span>
        </div>
        <span className="font-medium dark:text-gray-200">{numberFormatter(referrer.count)}</span>
      </div>
    )
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderList() {
    if (this.state.referrers && this.state.referrers.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500">
            <span>Source</span>
            <span>{this.label()}</span>
          </div>

          <FlipMove>
            {this.state.referrers.map(this.renderReferrer.bind(this))}
          </FlipMove>
          <MoreLink site={this.props.site} list={this.state.referrers} endpoint="sources" />
        </React.Fragment>
      )
    } else {
      return <div className="font-medium text-center text-gray-500 mt-44">No data yet</div>
    }
  }

  renderContent() {
    return (
      <LazyLoader onVisible={this.onVisible}>
        <div id="sources" className="flex justify-between w-full">
          <h3 className="font-bold dark:text-gray-100">Top Sources</h3>
          { this.props.renderTabs() }
        </div>
        { this.state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderList() }
        </FadeIn>
      </LazyLoader>
    )
  }

  render() {
    return (
      <div className="relative p-4 bg-white rounded shadow-xl stats-item dark:bg-gray-825" style={{height: '436px'}}>
          { this.renderContent() }
      </div>
    )
  }
}

const UTM_TAGS = {
  utm_medium: {label: 'UTM Medium', endpoint: 'utm_mediums'},
  utm_source: {label: 'UTM Source', endpoint: 'utm_sources'},
  utm_campaign: {label: 'UTM Campaign', endpoint: 'utm_campaigns'},
}

class UTMSources extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchReferrers()
    if (this.props.timer) this.props.timer.onTick(this.fetchReferrers.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query || this.props.tab !== prevProps.tab) {
      this.setState({loading: true, referrers: null})
      this.fetchReferrers()
    }
  }

  showNoRef() {
    return this.props.query.period === 'realtime'
  }

  fetchReferrers() {
    const endpoint = UTM_TAGS[this.props.tab].endpoint
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/${endpoint}`, this.props.query, {show_noref: this.showNoRef()})
      .then((res) => this.setState({loading: false, referrers: res}))
  }

  renderReferrer(referrer) {
    const query = new URLSearchParams(window.location.search)
    query.set(this.props.tab, referrer.name)

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={referrer.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={referrer.count} all={this.state.referrers} bg="bg-blue-50 dark:bg-gray-500 dark:bg-opacity-15" />
          <span className="flex px-2 dark:text-gray-300" style={{marginTop: '-26px'}} >
            <Link className="block truncate hover:underline" to={{search: query.toString()}}>
              { referrer.name }
            </Link>
          </span>
        </div>
        <span className="font-medium dark:text-gray-200">{numberFormatter(referrer.count)}</span>
      </div>
    )
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderList() {
    if (this.state.referrers && this.state.referrers.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>{UTM_TAGS[this.props.tab].label}</span>
            <span>{this.label()}</span>
          </div>

          <FlipMove>
            {this.state.referrers.map(this.renderReferrer.bind(this))}
          </FlipMove>
          <MoreLink site={this.props.site} list={this.state.referrers} endpoint={UTM_TAGS[this.props.tab].endpoint} />
        </React.Fragment>
      )
    } else {
      return <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">No data yet</div>
    }
  }

  renderContent() {
    return (
      <React.Fragment>
        <div className="flex justify-between w-full">
          <h3 className="font-bold dark:text-gray-100">Top sources</h3>
          { this.props.renderTabs() }
        </div>
        { this.state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderList() }
        </FadeIn>
      </React.Fragment>
    )
  }

  render() {
    return (
      <div className="relative p-4 bg-white rounded shadow-xl stats-item dark:bg-gray-825" style={{height: '436px'}}>
        { this.renderContent() }
      </div>
    )
  }
}

export default class SourceList extends React.Component {
  constructor(props) {
    super(props)
    this.tabKey = 'sourceTab__' + props.site.domain
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      tab: storedTab || 'all'
    }
  }

  setTab(tab) {
    return () => {
      storage.setItem(this.tabKey, tab)
      this.setState({tab})
    }
  }

  renderTabs() {
    const activeClass = 'inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold border-b-2 border-indigo-700 dark:border-indigo-500'
    const defaultClass = 'hover:text-indigo-600 cursor-pointer'
    return (
      <ul className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
        <li className={this.state.tab === 'all' ? activeClass : defaultClass} onClick={this.setTab('all')}>All</li>
        <li className={this.state.tab === 'utm_medium' ? activeClass : defaultClass} onClick={this.setTab('utm_medium')}>Medium</li>
        <li className={this.state.tab === 'utm_source' ? activeClass : defaultClass} onClick={this.setTab('utm_source')}>Source</li>
        <li className={this.state.tab === 'utm_campaign' ? activeClass : defaultClass} onClick={this.setTab('utm_campaign')}>Campaign</li>
      </ul>
    )
  }

  render() {
    if (this.state.tab === 'all') {
      return <AllSources tab={this.state.tab} setTab={this.setTab.bind(this)} renderTabs={this.renderTabs.bind(this)} {...this.props} />
    } else if (this.state.tab === 'utm_medium') {
      return <UTMSources tab={this.state.tab} setTab={this.setTab.bind(this)} renderTabs={this.renderTabs.bind(this)} {...this.props} />
    } else if (this.state.tab === 'utm_source') {
      return <UTMSources tab={this.state.tab} setTab={this.setTab.bind(this)} renderTabs={this.renderTabs.bind(this)} {...this.props} />
    } else if (this.state.tab === 'utm_campaign') {
      return <UTMSources tab={this.state.tab} setTab={this.setTab.bind(this)} renderTabs={this.renderTabs.bind(this)} {...this.props} />
    }
  }
}
