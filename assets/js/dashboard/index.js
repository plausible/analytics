import React from 'react';
import { withRouter } from 'react-router-dom'

import Historical from './historical'
import Realtime from './realtime'
import {parseQuery} from './query'
import * as api from './api'
import { ThemeContext } from './theme-context'


const THIRTY_SECONDS = 30000

class Timer {
  constructor() {
    this.listeners = []
    this.intervalId = setInterval(this.dispatchTick.bind(this), THIRTY_SECONDS)
  }

  onTick(listener) {
    this.listeners.push(listener)
  }

  dispatchTick() {
    for (const listener of this.listeners) {
      listener()
    }
  }
}

class DashboardWrapper extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      dark: document.querySelector('html').classList.contains('dark') || false
    };

    this.mutationObserver = new MutationObserver((mutationsList, observer) => {
      mutationsList.forEach(mutation => {
        if (mutation.attributeName === 'class') {
          this.setState({ dark: mutation.target.classList.contains('dark') });
        }
      });
    });
  }

  componentDidMount() {
    this.mutationObserver.observe(document.querySelector('html'), { attributes: true });
  }

  componentWillUnmount() {
    this.mutationObserver.disconnect();
  }

  render() {
    return (
      <ThemeContext.Provider value={this.state.dark}>
        <Dashboard {...this.props}/>
      </ThemeContext.Provider>
    );
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
      return <Realtime timer={this.state.timer} site={this.props.site} loggedIn={this.props.loggedIn} query={this.state.query} />
    } else {
      return <Historical timer={this.state.timer} site={this.props.site} loggedIn={this.props.loggedIn} query={this.state.query} />
    }
  }
}

export default withRouter(DashboardWrapper)
