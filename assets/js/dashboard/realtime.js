import React from 'react';

import Datepicker from './datepicker'
import SiteSwitcher from './site-switcher'
import Filters from './filters'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Locations from './stats/locations'
import Devices from './stats/devices'
import Behaviours from './stats/behaviours'
import { withPinnedHeader } from './pinned-header-hoc';
import { statsBoxClass } from './index';

class Realtime extends React.Component {
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
        <VisitorGraph site={this.props.site} query={this.props.query} lastLoadTimestamp={this.props.lastLoadTimestamp} />
        <div className="w-full md:flex">
          <div className={ statsBoxClass }>
            <Sources site={this.props.site} query={this.props.query} />
          </div>
          <div className={ statsBoxClass }>
            <Pages site={this.props.site} query={this.props.query} />
          </div>
        </div>
        <div className="w-full md:flex">
          <div className={ statsBoxClass }>
            <Locations site={this.props.site} query={this.props.query} />
          </div>
          <div className={ statsBoxClass }>
            <Devices site={this.props.site} query={this.props.query} />
          </div>
        </div>
        <Behaviours site={this.props.site} query={this.props.query} currentUserRole={this.props.currentUserRole} />
      </div>
    )
  }
}

export default withPinnedHeader(Realtime, '#stats-container-top');
