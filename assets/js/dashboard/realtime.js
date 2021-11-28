import React from 'react';

import Datepicker from './datepicker'
import SiteSwitcher from './site-switcher'
import Filters from './filters'
import VisitorGraph from './stats/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Locations from './stats/locations'
import Devices from './stats/devices'
import Conversions from './stats/conversions'
import { withPinnedHeader } from './pinned-header-hoc';

class Realtime extends React.Component {
  renderConversions() {
    if (this.props.site.hasGoals) {
      return (
        <div className="items-start justify-between block w-full mt-6 md:flex">
          <Conversions site={this.props.site} query={this.props.query} title="Goal Conversions (last 30 min)" />
        </div>
      )
    }

    return null
  }

  render() {
    const navClass = this.props.site.embedded ? 'relative' : 'sticky'

    return (
      <div className="mb-12">
        <div id="stats-container-top"></div>
        <div className={`${navClass} top-0 sm:py-3 py-2 z-10 ${this.props.stuck && !this.props.site.embedded ? 'fullwidth-shadow bg-gray-50 dark:bg-gray-850' : ''}`}>
          <div className="items-center w-full flex">
            <div className="flex items-center w-full">
              <SiteSwitcher site={this.props.site} loggedIn={this.props.loggedIn} currentUserRole={this.props.currentUserRole} />
              <Filters className="flex" site={this.props.site} query={this.props.query} history={this.props.history} />
            </div>
            <Datepicker site={this.props.site} query={this.props.query} />
          </div>
        </div>
        <VisitorGraph site={this.props.site} query={this.props.query} timer={this.props.timer} />
        <div className="items-start justify-between block w-full md:flex">
          <Sources site={this.props.site} query={this.props.query} timer={this.props.timer} />
          <Pages site={this.props.site} query={this.props.query} timer={this.props.timer} />
        </div>
        <div className="items-start justify-between block w-full md:flex">
          <Locations site={this.props.site} query={this.props.query} timer={this.props.timer} />
          <Devices site={this.props.site} query={this.props.query} timer={this.props.timer} />
        </div>

        { this.renderConversions() }
      </div>
    )
  }
}

export default withPinnedHeader(Realtime, '#stats-container-top');
