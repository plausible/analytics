import React from 'react';

import Bar from './bar'
import * as api from '../api'

const EXPLANATION = {
  'Mobile': 'up to 576px',
  'Tablet': '576px to 992px',
  'Laptop': '992px to 1440px',
  'Desktop': 'above 1440px',
}

function iconFor(screenSize) {
  if (screenSize === 'Mobile') {
    return (
      <svg width="16px" height="16px" style={{transform: 'translateY(3px)'}} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="feather feather-smartphone"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12" y2="18"/></svg>
    )
  } else if (screenSize === 'Tablet') {
    return (
      <svg width="16px" height="16px" style={{transform: 'translateY(3px)'}} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="feather feather-tablet"><rect x="4" y="2" width="16" height="20" rx="2" ry="2" transform="rotate(180 12 12)"/><line x1="12" y1="18" x2="12" y2="18"/></svg>
    )
  } else if (screenSize === 'Laptop') {
    return (
      <svg width="16px" height="16px" style={{transform: 'translateY(3px)'}} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="feather feather-laptop"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="2" y1="20" x2="22" y2="20"/></svg>
    )
  } else if (screenSize === 'Desktop') {
    return (
      <svg width="16px" height="16px" style={{transform: 'translateY(3px)'}} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="feather feather-monitor"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
    )
  }
}

export default class ScreenSizes extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchScreenSizes()
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
      <React.Fragment key={size.name}>
        <div className="flex items-center justify-between my-2">
          <span tooltip={EXPLANATION[size.name]}>
            { iconFor(size.name) }
            <span className="ml-1">{size.name}</span>
          </span>
          <span tooltip={`${size.count} visitors`}>{size.percentage}%</span>
        </div>
        <Bar count={size.count} all={this.state.sizes} color="teal" />
      </React.Fragment>
    )
  }

  render() {
    if (this.state.loading) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4" style={{height: '405px'}}>
          <div className="loading my-32 mx-auto"><div></div></div>
        </div>
      )
    } else if (this.state.sizes) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4" style={{height: '405px'}}>
          <div className="text-center">
            <h2>Screen Sizes</h2>
            <div className="text-grey-darker mt-1">by visitors</div>
          </div>

          <div className="mt-8">
            { this.state.sizes.map(this.renderScreenSize.bind(this)) }
          </div>
        </div>
      )
    }
  }
}
