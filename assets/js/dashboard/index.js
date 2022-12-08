import React from 'react';
import { withRouter } from 'react-router-dom'

import Historical from './historical'
import Realtime from './realtime'
import {parseQuery} from './query'
import * as api from './api'
import { withComparisonProvider } from './comparison-provider-hoc';

class Dashboard extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      query: parseQuery(props.location.search, this.props.site),
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
      return <Realtime site={this.props.site} loggedIn={this.props.loggedIn} currentUserRole={this.props.currentUserRole} query={this.state.query} />
    } else {
      return <Historical site={this.props.site} loggedIn={this.props.loggedIn} currentUserRole={this.props.currentUserRole} query={this.state.query} />
    }
  }
}

export default withRouter(withComparisonProvider(Dashboard))
