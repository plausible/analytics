import React from 'react';

import Datepicker from './datepicker'
import SiteSwitcher from './site-switcher'
import Filters from './filters'
import CurrentVisitors from './stats/current-visitors'
import VisitorGraph from './stats/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages/'
import Countries from './stats/countries'
import Devices from './stats/devices'
import Conversions from './stats/conversions'
import { withPinnedHeader } from './pinned-header-hoc';

class Historical extends React.Component {
  renderConversions() {
    if (this.props.site.hasGoals) {
      return (
        <div className="items-start justify-between block w-full mt-6 md:flex">
          <Conversions site={this.props.site} query={this.props.query} />
        </div>
      )
    }
  }

  render() {
    const navClass = this.props.site.embedded ? 'relative' : 'sticky'

    return (
      <div className="mb-12">
        <div id="stats-container-top"></div>
        <div className={`${navClass} top-0 sm:py-3 py-1 z-9 ${this.props.stuck && !this.props.site.embedded ? 'z-10 fullwidth-shadow bg-gray-50 dark:bg-gray-850' : ''}`}>
          <div className="items-center w-full sm:flex">
            <div className="flex items-center w-full mb-2 sm:mb-0">
              <SiteSwitcher site={this.props.site} loggedIn={this.props.loggedIn} currentUserRole={this.props.currentUserRole} />
              <CurrentVisitors timer={this.props.timer} site={this.props.site} query={this.props.query} />
              <Filters query={this.props.query} history={this.props.history} />
            </div>
            <Datepicker site={this.props.site} query={this.props.query} />
          </div>
        </div>
        <VisitorGraph site={this.props.site} query={this.props.query} />
        <div className="items-start justify-between block w-full md:flex">
          <Sources site={this.props.site} query={this.props.query} />
          <Pages site={this.props.site} query={this.props.query} />
        </div>
        <div className="items-start justify-between block w-full md:flex">
          <Countries site={this.props.site} query={this.props.query} />
          <Devices site={this.props.site} query={this.props.query} />
        </div>
        { this.renderConversions() }
      </div>
    )
  }
}

export default withPinnedHeader(Historical, '#stats-container-top');
