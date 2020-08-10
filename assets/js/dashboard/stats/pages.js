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

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={page.name}>
        <div className="w-full h-8 truncate" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={page.count} all={this.state.pages} bg="bg-orange-50" />
          <Link to={{search: query.toString()}} className="block px-2 hover:underline" style={{marginTop: '-26px'}}>{page.name}</Link>
        </div>
        <span className="font-medium">{numberFormatter(page.count)}</span>
      </div>
    )
  }

  label() {
    const filters = this.props.query.filters
    if (this.props.query.period === 'realtime') {
      return 'Active visitors'
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
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>Page url</span>
            <span>{ this.label() }</span>
          </div>

          <FlipMove>
            { this.state.pages.map(this.renderPage.bind(this)) }
          </FlipMove>
        </React.Fragment>
      )
    } else {
      return <div className="text-center mt-44 font-medium text-gray-500">No data yet</div>
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
          <h3 className="font-bold">{this.title()}</h3>
          { this.renderList() }
          <MoreLink site={this.props.site} list={this.state.pages} endpoint="pages" />
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <div className="stats-item relative bg-white shadow-xl rounded p-4" style={{height: '436px'}}>
        { this.state.loading && <div className="loading mt-44 mx-auto"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderContent() }
        </FadeIn>
      </div>
    )
  }
}
