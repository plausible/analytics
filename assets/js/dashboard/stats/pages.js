import React from 'react';

import FadeIn from '../fade-in'
import Bar from './bar'
import MoreLink from './more-link'
import numberFormatter from '../number-formatter'
import { eventName } from '../query'
import * as api from '../api'

export default class Pages extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true
    }
  }

  componentDidMount() {
    this.fetchPages()
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, pages: null})
      this.fetchPages()
    }
  }

  fetchPages() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/pages`, this.props.query)
      .then((res) => this.setState({loading: false, pages: res}))
  }

  renderPage(page) {
    return (
      <div className="flex items-center justify-between my-1 text-sm" key={page.name}>
        <div className="w-full h-8 truncate" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={page.count} all={this.state.pages} color="orange" />
          <span className="block px-2" style={{marginTop: '-23px'}}>{page.name}</span>
        </div>
        <span className="font-medium">{numberFormatter(page.count)}</span>
      </div>
    )
  }

  renderList() {
    if (this.state.pages.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-4 mb-2 justify-between text-grey-dark text-xs font-bold tracking-wide">
            <span>Page url</span>
            <span>Visitors</span>
          </div>

          { this.state.pages.map(this.renderPage.bind(this)) }
        </React.Fragment>
      )
    } else {
      return <div className="text-center mt-44 font-medium text-grey-dark">No data yet</div>
    }
  }

  renderContent() {
    if (this.state.pages) {
      return (
        <React.Fragment>
          <h3>Top Pages</h3>
          { this.renderList() }
          <MoreLink site={this.props.site} list={this.state.pages} endpoint="pages" />
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <div className="stats-item bg-white shadow-xl rounded p-4" style={{height: '436px'}}>
        { this.state.loading && <div className="loading mt-44 mx-auto"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderContent() }
        </FadeIn>
      </div>
    )
  }
}
