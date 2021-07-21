import React from 'react';

import StickyNav from './pinned-header-hoc';
import CurrentVisitors from './stats/current-visitors'
import VisitorGraph from './stats/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages/'
import Countries from './stats/countries'
import Devices from './stats/devices'
import Conversions from './stats/conversions'

export default class Realtime extends React.Component {
  renderConversions() {
    if (this.props.site.hasGoals) {
      return (
        <div className="items-start justify-between block w-full mt-6 md:flex">
          <Conversions site={this.props.site} query={this.props.query} title="Goal Conversions (last 30 min)" />
        </div>
      )
    }
  }

  render() {
    const navClass = this.props.site.embedded ? 'relative' : 'sticky'

    return (
      <div className="mb-12">
        <StickyNav site={this.props.site} query={this.props.query} timer={this.props.timer} />
        <VisitorGraph site={this.props.site} query={this.props.query} timer={this.props.timer} />
        <div className="items-start justify-between block w-full md:flex">
          <Sources site={this.props.site} query={this.props.query} timer={this.props.timer} />
          <Pages site={this.props.site} query={this.props.query} timer={this.props.timer} />
        </div>
        <div className="items-start justify-between block w-full md:flex">
          <Countries site={this.props.site} query={this.props.query} timer={this.props.timer} />
          <Devices site={this.props.site} query={this.props.query} timer={this.props.timer} />
        </div>

        { this.renderConversions() }
      </div>
    )
  }
}
