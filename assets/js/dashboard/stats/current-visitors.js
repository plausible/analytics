import React from 'react';

const THIRTY_SECONDS = 30000

export default class CurrentVisitors extends React.Component {
  constructor(props) {
    super(props)
    this.state = {currentVisitors: null}
  }

  componentDidMount() {
    this.updateCount().then(() => {
      this.intervalId = setInterval(this.updateCount.bind(this), THIRTY_SECONDS)
    })
  }

  componentWillUnMount() {
    clearInverval(this.intervalId)
  }

  updateCount() {
    return fetch(`/api/stats/${encodeURIComponent(this.props.site.domain)}/current-visitors`)
      .then(res => res.json())
      .then((res) => this.setState({currentVisitors: res}))
  }

  render() {
    if (this.state.currentVisitors !== null) {
      return (
        <div className="text-sm font-bold text-gray-500 mt-1">
          <svg className="w-2 mr-2 fill-current text-green-500 inline" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
            <circle cx="8" cy="8" r="8"/>
          </svg>
          {this.state.currentVisitors} current visitors
        </div>
      )
    } else {
      return null
    }
  }
}
