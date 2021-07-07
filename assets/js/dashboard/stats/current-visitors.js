import React from 'react';
import * as api from '../api'
import { Link } from 'react-router-dom'

export default class CurrentVisitors extends React.Component {
  constructor(props) {
    super(props)
    this.state = {currentVisitors: null}
  }

  componentDidMount() {
    this.updateCount()
    this.props.timer.onTick(this.updateCount.bind(this))
  }

  updateCount() {
    return api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/current-visitors`)
      .then((res) => this.setState({currentVisitors: res}))
  }

  render() {
    const query = new URLSearchParams(window.location.search)
    query.set('period', 'realtime')

    const { currentVisitors } = this.state;
    if (currentVisitors !== null) {
      return (
        <Link to={{search: query.toString()}} className="block ml-1 sm:ml-2 mr-auto text-xs sm:text-sm font-bold text-gray-500 dark:text-gray-300">
          <svg className="inline w-2 mr-1 sm:mr-2 text-green-500 fill-current" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
            <circle cx="8" cy="8" r="8"/>
          </svg>
          {currentVisitors} current visitor{currentVisitors === 1 ? '' : 's'}
        </Link>
      )
    } else {
      return null
    }
  }
}
