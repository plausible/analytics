import React from 'react';

import Bar from './bar'
import MoreLink from './more-link'
import numberFormatter from '../number-formatter'

export default class Pages extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true
    }
  }

  componentDidMount() {
    fetch(`/api/stats/${this.props.site.domain}/pages${window.location.search}`)
      .then((res) => res.json())
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
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4">
          <div className="loading my-32 mx-auto"><div></div></div>
        </div>
      )
    } else if (this.state.pages) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4">
          <div className="text-center">
            <h2>Top Pages</h2>
            <div className="text-grey-darker mt-1">by pageviews</div>
          </div>

          <div className="mt-8">
            { this.state.pages.map(this.renderPage.bind(this)) }
          </div>
          <MoreLink site={this.props.site} list={this.state.pages} endpoint="pages" />
        </div>
      )
    }
  }
}
