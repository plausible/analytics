import React from 'react';

import Datepicker from './datepicker'
import Filters from './filters'
import CurrentVisitors from './stats/current-visitors'
import VisitorGraph from './stats/visitor-graph'
import Referrers from './stats/referrers'
import Pages from './stats/pages'
import Countries from './stats/countries'
import Devices from './stats/devices'
import * as api from './api'

export default class Stats extends React.Component {
  render() {
    return (
      <div className="mb-12">
        <div className="w-full sm:flex justify-between items-center">
          <div className="w-full flex items-center">
            <h2 className="text-left mr-8 font-semibold text-xl">Analytics for <a href={`http://${this.props.site.domain}`} target="_blank">{this.props.site.domain}</a></h2>
          </div>
          <Datepicker site={this.props.site} query={this.props.query} />
        </div>
        <Filters query={this.props.query} history={this.props.history} />
        <VisitorGraph site={this.props.site} query={this.props.query} timer={this.props.timer} />
        <div className="w-full block md:flex items-start justify-between">
          <Referrers site={this.props.site} query={this.props.query} timer={this.props.timer} />
          <Pages site={this.props.site} query={this.props.query} timer={this.props.timer} />
        </div>
        <div className="w-full block md:flex items-start justify-between">
          <Countries site={this.props.site} query={this.props.query} timer={this.props.timer} />
          <Devices site={this.props.site} query={this.props.query} timer={this.props.timer} />
        </div>
      </div>
    )
  }
}
