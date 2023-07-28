import React from 'react';
import { withRouter } from 'react-router-dom'

import Historical from './historical'
import Realtime from './realtime'
import {parseQuery} from './query'
import * as api from './api'
import { withComparisonProvider } from './comparison-provider-hoc';

export const statsBoxClass = "stats-item relative w-full mt-6 p-4 flex flex-col bg-white dark:bg-gray-825 shadow-xl rounded"

class Dashboard extends React.Component {
  constructor(props) {
    super(props)
    this.updateLastLoadTimestamp = this.updateLastLoadTimestamp.bind(this)
    this.state = {
      query: parseQuery(props.location.search, this.props.site),
      lastLoadTimestamp: new Date()
    }
  }

  componentDidMount() {
    document.addEventListener('tick', this.updateLastLoadTimestamp)
  }

  componentDidUpdate(prevProps) {
    if (prevProps.location.search !== this.props.location.search) {
      api.cancelAll()
      this.setState({query: parseQuery(this.props.location.search, this.props.site)})
      this.updateLastLoadTimestamp()
    }
  }

  updateLastLoadTimestamp() {
    this.setState({lastLoadTimestamp: new Date()})
  }

  render() {
    const { site, loggedIn, currentUserRole } = this.props
    const { query, lastLoadTimestamp } = this.state

    if (this.state.query.period === 'realtime') {
      return <Realtime site={site} loggedIn={loggedIn} currentUserRole={currentUserRole} query={query} lastLoadTimestamp={lastLoadTimestamp}/>
    } else {
      return <Historical site={site} loggedIn={loggedIn} currentUserRole={currentUserRole} query={query} lastLoadTimestamp={lastLoadTimestamp}/>
    }
  }
}

export default withRouter(withComparisonProvider(Dashboard))
