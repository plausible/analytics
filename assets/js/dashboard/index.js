import React from 'react';
import { withRouter } from 'react-router-dom'

import Datepicker from './datepicker'
import Filters from './filters'
import CurrentVisitors from './stats/current-visitors'
import VisitorGraph from './stats/visitor-graph'
import Referrers from './stats/referrers'
import Pages from './stats/pages'
import Countries from './stats/countries'
import Browsers from './stats/browsers'
import OperatingSystems from './stats/operating-systems'
import ScreenSizes from './stats/screen-sizes'
import Conversions from './stats/conversions'
import {parseQuery} from './query'

class Stats extends React.Component {
  constructor(props) {
    super(props)
    this.state = {query: parseQuery(props.location.search, this.props.site)}
  }

  componentDidUpdate(prevProps) {
    if (prevProps.location.search !== this.props.location.search) {
      this.setState({query: parseQuery(this.props.location.search, this.props.site)})
    }
  }

  renderConversions() {
    if (this.props.site.hasGoals) {
      return (
        <div className="w-full block md:flex items-start justify-between mt-6">
          <Conversions site={this.props.site} query={this.state.query} />
        </div>
      )
    }
  }

  render() {
    return (
      <div className="mb-12">
        <div className="w-full sm:flex justify-between items-center">
          <div className="w-full flex items-center">
            <h2 className="text-left mr-8">Analytics for <a href={`//${this.props.site.domain}`} target="_blank">{this.props.site.domain}</a></h2>
            <CurrentVisitors site={this.props.site}  />
          </div>
          <Datepicker site={this.props.site} query={this.state.query} />
        </div>
        <Filters query={this.state.query} history={this.props.history} />
        <VisitorGraph site={this.props.site} query={this.state.query} />
        <div className="w-full block md:flex items-start justify-between mt-6">
          <Referrers site={this.props.site} query={this.state.query} />
          <Pages site={this.props.site} query={this.state.query} />
          <Countries site={this.props.site} query={this.state.query} />
        </div>
        <div className="w-full block md:flex items-start justify-between mt-6">
          <Browsers site={this.props.site} query={this.state.query} />
          <OperatingSystems site={this.props.site} query={this.state.query} />
          <ScreenSizes site={this.props.site} query={this.state.query} />
        </div>

        { this.renderConversions() }
      </div>
    )
  }
}

export default withRouter(Stats)
