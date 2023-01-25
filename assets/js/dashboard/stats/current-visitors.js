import React from 'react';
import { Link } from 'react-router-dom'
import * as api from '../api'
import * as url from '../util/url'
import { appliedFilters } from '../query';
import { Tooltip } from '../util/tooltip';
import { SecondsSinceLastLoad } from '../util/seconds-since-last-load';

export default class CurrentVisitors extends React.Component {
  constructor(props) {
    super(props)
    this.state = {currentVisitors: null}
    this.updateCount = this.updateCount.bind(this)
  }

  componentDidMount() {
    this.updateCount()
    document.addEventListener('tick', this.updateCount)
  }

  componentWillUnmount() {
    document.removeEventListener('tick', this.updateCount)
  }

  updateCount() {
    return api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/current-visitors`)
      .then((res) => this.setState({currentVisitors: res}))
  }

  tooltipInfo() {
    return (
      <div>
        <p className="whitespace-nowrap text-small">Last updated <SecondsSinceLastLoad lastLoadTimestamp={this.props.lastLoadTimestamp} />s ago</p>
        <p className="whitespace-nowrap font-normal text-xs">Click to view realtime dashboard</p>
      </div>
    )
  }

  render() {
    if (appliedFilters(this.props.query).length >= 1) { return null }
    const { currentVisitors } = this.state;

    if (currentVisitors !== null) {
      return (
        <Tooltip info={this.tooltipInfo()} boundary={this.props.tooltipBoundary}>
          <Link to={url.setQuery('period', 'realtime')} className="block ml-1 md:ml-2 mr-auto text-xs md:text-sm font-bold text-gray-500 dark:text-gray-300">
            <svg className="inline w-2 mr-1 md:mr-2 text-green-500 fill-current" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
              <circle cx="8" cy="8" r="8" />
            </svg>
            {currentVisitors} <span className="hidden sm:inline-block">current visitor{currentVisitors === 1 ? '' : 's'}</span>
          </Link>
        </Tooltip>
      )
    }

    return null
  }
}
