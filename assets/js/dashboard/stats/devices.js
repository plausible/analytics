import React from 'react';

import Bar from './bar'
import MoreLink from './more-link'
import * as api from '../api'


function FadeIn({show, children}) {
  const className = show ? "fade-enter-active" : "fade-enter"

  return <div className={className}>{children}</div>
}

const EXPLANATION = {
  'Mobile': 'up to 576px',
  'Tablet': '576px to 992px',
  'Laptop': '992px to 1440px',
  'Desktop': 'above 1440px',
}

function iconFor(screenSize) {
  if (screenSize === 'Mobile') {
    return (
      <svg width="16px" height="16px" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="feather -mt-px"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12" y2="18"/></svg>
    )
  } else if (screenSize === 'Tablet') {
    return (
      <svg width="16px" height="16px" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="feather -mt-px"><rect x="4" y="2" width="16" height="20" rx="2" ry="2" transform="rotate(180 12 12)"/><line x1="12" y1="18" x2="12" y2="18"/></svg>
    )
  } else if (screenSize === 'Laptop') {
    return (
      <svg width="16px" height="16px" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="feather -mt-px"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="2" y1="20" x2="22" y2="20"/></svg>
    )
  } else if (screenSize === 'Desktop') {
    return (
      <svg width="16px" height="16px" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="feather -mt-px"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
    )
  }
}

class ScreenSizes extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchScreenSizes()
    if (this.props.timer) this.props.timer.onTick(this.fetchScreenSizes.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, sizes: null})
      this.fetchScreenSizes()
    }
  }

  fetchScreenSizes() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/screen-sizes`, this.props.query)
      .then((res) => this.setState({loading: false, sizes: res}))
  }

  renderScreenSize(size) {
    return (
      <div className="flex items-center justify-between my-1 text-sm" key={size.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={size.count} all={this.state.sizes} bg="bg-green-50" />
          <span tooltip={EXPLANATION[size.name]} className="block px-2" style={{marginTop: '-26px'}}>{iconFor(size.name)} {size.name}</span>
        </div>
        <span className="font-medium">{size.percentage}%</span>
      </div>
    )
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderList() {
    if (this.state.sizes && this.state.sizes.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>Screen size</span>
            <span>{ this.label() }</span>
          </div>
          { this.state.sizes && this.state.sizes.map(this.renderScreenSize.bind(this)) }
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

class Browsers extends React.Component {
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
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/browsers`, this.props.query)
      .then((res) => this.setState({loading: false, browsers: res}))
  }

  renderBrowser(browser) {
    return (
      <div className="flex items-center justify-between my-1 text-sm" key={browser.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={browser.count} all={this.state.browsers} bg="bg-green-50" />
          <span className="block px-2" style={{marginTop: '-26px'}}>{browser.name}</span>
        </div>
        <span className="font-medium">{browser.percentage}%</span>
      </div>
    )
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderList() {
    if (this.state.browsers && this.state.browsers.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>Browser</span>
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

class OperatingSystems extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchOperatingSystems()
    if (this.props.timer) this.props.timer.onTick(this.fetchOperatingSystems.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, operatingSystems: null})
      this.fetchOperatingSystems()
    }
  }

  fetchOperatingSystems() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/operating-systems`, this.props.query)
      .then((res) => this.setState({loading: false, operatingSystems: res}))
  }

  renderOperatingSystem(os) {
    return (
      <div className="flex items-center justify-between my-1 text-sm" key={os.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={os.count} all={this.state.operatingSystems} bg="bg-green-50" />
          <span className="block px-2" style={{marginTop: '-26px'}}>{os.name}</span>
        </div>
        <span className="font-medium">{os.percentage}%</span>
      </div>
    )
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderList() {
    if (this.state.operatingSystems && this.state.operatingSystems.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>Operating system</span>
            <span>{ this.label() }</span>
          </div>
          { this.state.operatingSystems && this.state.operatingSystems.map(this.renderOperatingSystem.bind(this)) }
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

export default class Devices extends React.Component {
  constructor(props) {
    super(props)
    this.state = {mode: 'size'}
  }

  renderContent() {
    if (this.state.mode === 'size') {
      return <ScreenSizes site={this.props.site} query={this.props.query} timer={this.props.timer} />
    } else if (this.state.mode === 'browser') {
      return <Browsers site={this.props.site} query={this.props.query} timer={this.props.timer} />
    } else if (this.state.mode === 'os') {
      return <OperatingSystems site={this.props.site} query={this.props.query} timer={this.props.timer} />
    }
  }

  setMode(mode) {
    return () => {
      this.setState({mode})
    }
  }

  renderPill(name, mode) {
    const isActive = this.state.mode === mode
    const extraClass = name === 'OS' ? '' : ' border-r border-gray-300'

    if (isActive) {
      return <span className={"inline-block shadow-inner text-sm font-bold py-1 px-4" + extraClass}>{name}</span>
    } else {
      return <span className={"inline-block cursor-pointer bg-gray-100 text-sm font-bold py-1 px-4" + extraClass} onClick={this.setMode(mode)}>{name}</span>
    }
  }

  render() {
    return (
      <div className="stats-item">
        <div className="bg-white shadow-xl rounded p-4 relative" style={{height: '436px'}}>
          <h3 className="font-bold">Devices</h3>

          <div className="rounded border border-gray-300 absolute" style={{top: '1rem', right: '1rem'}}>
            { this.renderPill('Size', 'size') }
            { this.renderPill('Browser', 'browser') }
            { this.renderPill('OS', 'os') }
          </div>

          { this.renderContent() }

        </div>
      </div>
    )
  }
}
