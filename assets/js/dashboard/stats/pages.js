import React from 'react';

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
      <React.Fragment key={page.name}>
        <div className="flex items-center justify-between my-2">
          <span className="truncate" style={{maxWidth: '80%'}}>{page.name}</span>
          <span>{numberFormatter(page.count)}</span>
        </div>
        <Bar count={page.count} all={this.state.pages} color="orange" />
      </React.Fragment>
    )
  }

  render() {
    if (this.state.loading) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4 relative" style={{height: '405px'}}>
          <div className="loading my-32 mx-auto"><div></div></div>
        </div>
      )
    } else if (this.state.pages) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4 relative" style={{height: '405px'}}>
          <div className="text-center">
            <h2>Top Pages</h2>
            <div className="text-grey-darker mt-1">by {eventName(this.props.query)}</div>
          </div>

          <div className="mt-8">
            { this.state.pages.map(this.renderPage.bind(this)) }
          </div>
          <MoreLink site={this.props.site} endpoint="pages" />
        </div>
      )
    }
  }
}
