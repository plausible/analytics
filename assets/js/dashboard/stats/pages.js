import React from 'react';
import { Link } from 'react-router-dom'
import FlipMove from 'react-flip-move';

import FadeIn from '../fade-in'
import Bar from './bar'
import MoreLink from './more-link'
import numberFormatter from '../number-formatter'
import { eventName } from '../query'
import * as api from '../api'

export default class Pages extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchPages()
    if (this.props.timer) this.props.timer.onTick(this.fetchPages.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, pages: null})
      this.fetchPages()
    }
  }

  fetchPages() {
    const {filters} = this.props.query
    if (filters.source || filters.referrer) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/entry-pages`, this.props.query)
        .then((res) => this.setState({loading: false, pages: res}))
    } else {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/pages`, this.props.query)
        .then((res) => this.setState({loading: false, pages: res}))
    }
  }

  renderPage(page) {
    const query = new URLSearchParams(window.location.search)
    query.set('page', page.name)
    const domain = new URL('https://' + this.props.site.domain)
    const externalLink = 'https://' + domain.host  + page.name

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={page.name}>
        <div className="w-full h-8 truncate" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={page.count} all={this.state.pages} bg="bg-orange-50 dark:bg-gray-500 dark:bg-opacity-15" />
          <span className="flex px-2 group dark:text-gray-300" style={{marginTop: '-26px'}} >
            <Link to={{pathname: window.location.pathname, search: query.toString()}} className="block hover:underline">{page.name}</Link>
            <a target="_blank" href={externalLink} className="hidden group-hover:block">
              <svg className="inline h-4 w-4 ml-1 -mt-1 text-gray-600 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
            </a>
          </span>
        </div>
        <span className="font-medium dark:text-gray-200">{numberFormatter(page.count)}</span>
      </div>
    )
  }

  label() {
    const filters = this.props.query.filters
    if (this.props.query.period === 'realtime') {
      return 'Current visitors'
    } else if (filters['source'] || filters['referrer']) {
      return 'Entrances'
    } else {
      return 'Visitors'
    }
  }

  renderList() {
    if (this.state.pages.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 dark:text-gray-400 text-xs font-bold tracking-wide">
            <span>Page url</span>
            <span>{ this.label() }</span>
          </div>

          <FlipMove>
            { this.state.pages.map(this.renderPage.bind(this)) }
          </FlipMove>
        </React.Fragment>
      )
    } else {
      return <div className="text-center mt-44 font-medium text-gray-500 dark:text-gray-400">No data yet</div>
    }
  }

  title() {
    const filters = this.props.query.filters
    return filters['source'] || filters['referrer'] ? 'Entry Pages' : 'Top Pages'
  }

  renderContent() {
    if (this.state.pages) {
      return (
        <React.Fragment>
          <h3 className="font-bold dark:text-gray-100">{this.title()}</h3>
          { this.renderList() }
          <MoreLink site={this.props.site} list={this.state.pages} endpoint="pages" />
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <div className="stats-item relative bg-white dark:bg-gray-825 shadow-xl rounded p-4" style={{height: '436px'}}>
        { this.state.loading && <div className="loading mt-44 mx-auto"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderContent() }
        </FadeIn>
      </div>
    )
  }
}
