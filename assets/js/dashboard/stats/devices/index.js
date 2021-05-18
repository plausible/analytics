import React from 'react';
import { Link } from 'react-router-dom'

import * as storage from '../../storage'
import LazyLoader from '../../lazy-loader'
import Browsers from './browsers'
import OperatingSystems from './operating-systems'
import FadeIn from '../../fade-in'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import MoreLink from '../more-link'
import * as api from '../../api'


const EXPLANATION = {
  'Mobile': 'up to 576px',
  'Tablet': '576px to 992px',
  'Laptop': '992px to 1440px',
  'Desktop': 'above 1440px',
}

function iconFor(screenSize) {
  if (screenSize === 'Mobile') {
    return (
      <svg width="16px" height="16px" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12" y2="18"/></svg>
    )
  } else if (screenSize === 'Tablet') {
    return (
      <svg width="16px" height="16px" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="4" y="2" width="16" height="20" rx="2" ry="2" transform="rotate(180 12 12)"/><line x1="12" y1="18" x2="12" y2="18"/></svg>
    )
  } else if (screenSize === 'Laptop') {
    return (
      <svg width="16px" height="16px" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="2" y1="20" x2="22" y2="20"/></svg>
    )
  } else if (screenSize === 'Desktop') {
    return (
      <svg width="16px" height="16px" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
    )
  }
}

class ScreenSizes extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
    this.onVisible = this.onVisible.bind(this)
  }

  onVisible() {
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
    const query = new URLSearchParams(window.location.search)
    query.set('screen', size.name)

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={size.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 6rem)'}}>
          <Bar count={size.count} all={this.state.sizes} bg="bg-green-50 dark:bg-gray-500 dark:bg-opacity-15" />
          <span tooltip={EXPLANATION[size.name]} className="flex px-2 dark:text-gray-300" style={{marginTop: '-26px'}} >
            <Link className="block truncate hover:underline" to={{search: query.toString()}}>
              {iconFor(size.name)} {size.name}
            </Link>
          </span>
        </div>
        <span className="font-medium dark:text-gray-200">{numberFormatter(size.count)} <span className="inline-block w-8 text-xs text-right">({size.percentage}%)</span></span>
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
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500">
            <span>Screen size</span>
            <span>{ this.label() }</span>
          </div>
          { this.state.sizes && this.state.sizes.map(this.renderScreenSize.bind(this)) }
        </React.Fragment>
      )
    } else {
      return <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">No data yet</div>
    }
  }

  render() {
    return (
      <LazyLoader onVisible={this.onVisible}>
        { this.state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderList() }
        </FadeIn>
      </LazyLoader>
    )
  }
}

export default class Devices extends React.Component {
  constructor(props) {
    super(props)
    this.tabKey = 'deviceTab__' + props.site.domain
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || 'size'
    }
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
      storage.setItem(this.tabKey, mode)
      this.setState({mode})
    }
  }

  renderPill(name, mode) {
    const isActive = this.state.mode === mode

    if (isActive) {
      return <li className="inline-block h-5 font-bold text-indigo-700 border-b-2 border-indigo-700 dark:text-indigo-500 dark:border-indigo-500">{name}</li>
    } else {
      return <li className="cursor-pointer hover:text-indigo-600" onClick={this.setMode(mode)}>{name}</li>
    }
  }

  render() {
    return (
      <div className="stats-item">
        <div className="relative p-4 bg-white rounded shadow-xl dark:bg-gray-825" style={{height: '436px'}}>

          <div className="flex justify-between w-full">
            <h3 className="font-bold dark:text-gray-100">Devices</h3>

            <ul className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
              { this.renderPill('Size', 'size') }
              { this.renderPill('Browser', 'browser') }
              { this.renderPill('OS', 'os') }
            </ul>
          </div>

          { this.renderContent() }

        </div>
      </div>
    )
  }
}
