import React from 'react';

import Datepicker from './datepicker'
import Filters from './filters'
import CurrentVisitors from './stats/current-visitors'
import VisitorGraph from './stats/visitor-graph'
import Referrers from './stats/referrers'
import Pages from './stats/pages'
import Countries from './stats/countries'
import Devices from './stats/devices'
import Conversions from './stats/conversions'

export default class Historical extends React.Component {
  renderConversions() {
    if (this.props.site.hasGoals) {
      return (
        <div className="w-full block md:flex items-start justify-between mt-6">
          <Conversions site={this.props.site} query={this.props.query} />
        </div>
      )
    }
  }

  render() {
    return (
      <div className="mb-12">
        <div className="w-full sm:flex justify-between items-center">
          <div className="w-full flex items-center">
            <h2 className="text-left mr-8 font-semibold text-xl">Analytics for <a href={`http://${this.props.site.domain}`} target="_blank">{this.props.site.domain}</a></h2>
            <CurrentVisitors timer={this.props.timer} site={this.props.site}  />
          </div>
          <Datepicker site={this.props.site} query={this.props.query} />
        </div>
        <Filters query={this.props.query} history={this.props.history} />
        <VisitorGraph site={this.props.site} query={this.props.query} />
        <div className="w-full block md:flex items-start justify-between">
          <Referrers site={this.props.site} query={this.props.query} />
          <Pages site={this.props.site} query={this.props.query} />
        </div>
        <div className="w-full block md:flex items-start justify-between">
          <Countries site={this.props.site} query={this.props.query} />
          <Devices site={this.props.site} query={this.props.query} />
        </div>
        { this.renderConversions() }
      </div>
    )
  }
}
