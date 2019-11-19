import React from 'react';

import Bar from './bar'
import MoreLink from './more-link'
import * as api from '../api'

export default class Browsers extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchBrowsers()
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, browsers: null})
      this.fetchBrowsers()
    }
  }

  fetchBrowsers() {
    api.get(`/api/stats/${this.props.site.domain}/browsers`, this.props.query)
      .then((res) => this.setState({loading: false, browsers: res}))
  }

  renderBrowser(browser) {
    return (
      <React.Fragment key={browser.name}>
        <div className="flex items-center justify-between my-2">
          <span className="truncate" style={{maxWidth: '80%'}}>{browser.name}</span>
          <span tooltip={`${browser.count} visitors`}>{browser.percentage}%</span>
        </div>
        <Bar count={browser.count} all={this.state.browsers} color="red" />
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
    } else if (this.state.browsers) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4">
          <div className="text-center">
            <h2>Browsers</h2>
            <div className="text-grey-darker mt-1">by visitors</div>
          </div>

          <div className="mt-8">
            { this.state.browsers.map(this.renderBrowser.bind(this)) }
          </div>
          <MoreLink site={this.props.site} list={this.state.browsers} endpoint="browsers" />
        </div>
      )
    }
  }
}
