import React from 'react';

import Datepicker from './datepicker'
import SiteSwitcher from './site-switcher'
import Filters from './filters'
import CurrentVisitors from './stats/current-visitors'
import VisitorGraph from './stats/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Locations from './stats/locations';
import Devices from './stats/devices'
import Conversions from './stats/conversions'
import { withPinnedHeader } from './pinned-header-hoc';

function Historical(props) {
  function renderConversions() {
    if (props.site.hasGoals) {
      return (
        <div className="items-start justify-between block w-full mt-6 md:flex">
          <Conversions site={props.site} query={props.query} />
        </div>
      )
    }

    return null
  }

  return (
    <div className="mb-12">
      <div id="stats-container-top"></div>
      <div className={`relative top-0 sm:py-3 py-2 z-10 ${props.stuck && !props.site.embedded ? 'sticky fullwidth-shadow bg-gray-50 dark:bg-gray-850' : ''}`}>
        <div className="items-center w-full flex">
          <div className="flex items-center w-full">
            <SiteSwitcher site={props.site} loggedIn={props.loggedIn} currentUserRole={props.currentUserRole} />
            <CurrentVisitors timer={props.timer} site={props.site} query={props.query} />
            <Filters className="flex" site={props.site} query={props.query} history={props.history} />
          </div>
          <Datepicker site={props.site} query={props.query} />
        </div>
      </div>
      <VisitorGraph site={props.site} query={props.query} />
      <div className="items-start justify-between block w-full md:flex">
        <Sources site={props.site} query={props.query} />
        <Pages site={props.site} query={props.query} />
      </div>
      <div className="items-start justify-between block w-full md:flex">
        <Locations site={props.site} query={props.query} />
        <Devices site={props.site} query={props.query} />
      </div>
      { renderConversions() }
    </div>
  )
}

export default withPinnedHeader(Historical, '#stats-container-top');
