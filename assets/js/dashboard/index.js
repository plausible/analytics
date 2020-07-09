import React from 'react';
import { withRouter } from 'react-router-dom'

import Historical from './historical'
import Realtime from './realtime'
import {parseQuery} from './query'
import * as api from './api'


const THIRTY_SECONDS = 5000

class Timer extends EventTarget {
  constructor() {
    super()
    this.intervalId = setInterval(this.dispatchTick.bind(this), THIRTY_SECONDS)
  }

  dispatchTick() {
    this.dispatchEvent(new Event('tick'));
  }
}

class Dashboard extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      query: parseQuery(props.location.search, this.props.site),
      timer: new Timer()
    }
  }

  componentDidUpdate(prevProps) {
    if (prevProps.location.search !== this.props.location.search) {
      api.cancelAll()
      this.setState({query: parseQuery(this.props.location.search, this.props.site)})
    }
  }

  render() {
    if (this.state.query.period === 'realtime') {
      return <Realtime timer={this.state.timer} site={this.props.site} query={this.state.query} />
    } else {
      return <Historical timer={this.state.timer} site={this.props.site} query={this.state.query} />
    }
  }
}

export default withRouter(Dashboard)
