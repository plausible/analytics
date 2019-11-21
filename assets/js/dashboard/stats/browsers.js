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
    const browsersPromise = api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/browsers`, this.props.query)
    const screenSizesPromise = api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/screen-sizes`, this.props.query)

    Promise.all([browsersPromise, screenSizesPromise]).then(([browsers, screenSizes]) => {
      this.setState({loading: false, browsers: browsers, screenSizes: screenSizes})
    })
  }

  renderBrowser(browser) {
    return (
      <div className="flex items-center justify-between my-4"  key={browser.name}>
        <div className="w-full" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={browser.count} all={this.state.browsers} color="blue" />
          <span className="block px-2 truncate" style={{marginTop: '-25px'}}>{browser.name}</span>
        </div>
        <span className="font-medium" tooltip={`${browser.count} visitors`}>{browser.percentage}%</span>
      </div>
    )
  }

  renderScreenSize(name) {
    const size = this.state.screenSizes.find(size => size.name === name)

    return (
			<div className="text-lg font-medium" tooltip={`${size.count} visitors`}>{size.percentage}%</div>
    )
  }

  renderDeviceTypes() {
    return (
      <div className="flex items-center mt-8 justify-between">
        <div className="text-center bg-grey-lightest py-3 rounded device-item">
          { this.renderScreenSize('Mobile') }
          <div className="mt-2">Mobile</div>
        </div>
        <div className="text-center bg-grey-lightest py-3 rounded device-item">
          { this.renderScreenSize('Tablet') }
          <div className="mt-2">Tablet</div>
        </div>
        <div className="text-center bg-grey-lightest py-3 rounded device-item">
					{ this.renderScreenSize('Laptop') }
          <div className="mt-2">Laptop</div>
        </div>
        <div className="text-center bg-grey-lightest py-3 rounded device-item">
					{ this.renderScreenSize('Desktop') }
          <div className="mt-2">Desktop</div>
        </div>
      </div>
    )
  }

  render() {
    if (this.state.loading) {
      return (
        <div className="stats-item">
          <div className="bg-white shadow-xl rounded p-4" style={{height: '424px'}}>
            <div className="loading my-32 mx-auto"><div></div></div>
          </div>
        </div>
      )
    } else if (this.state.browsers) {
      return (
        <div className="stats-item">
          <div className="bg-white shadow-xl rounded p-4 relative" style={{height: '424px'}}>
            <h3>Platforms</h3>

            <div className="rounded border border-grey-light absolute" style={{top: '1rem', right: '1rem'}}>
              <span className="inline-block shadow-inner text-xs font-bold py-1 px-4 border-r border-right border-grey-light">Browser</span>
              <span className="inline-block bg-grey-lighter text-sm font-bold px-4 py-1">OS</span>
            </div>

            <div className="flex items-center mt-6 mb-3 justify-between text-grey-dark text-xs font-bold tracking-wide">
              <span>BROWSER</span>
              <span>VISITORS</span>
            </div>

            { this.state.browsers.map(this.renderBrowser.bind(this)) }
          </div>
        </div>
      )
    }
  }
}
