import React from 'react';

import Datepicker from './datepicker'
import SiteSwitcher from './site-switcher'
import Filters from './filters'
import CurrentVisitors from './stats/current-visitors'
import VisitorGraph from './stats/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Countries from './stats/countries'
import Devices from './stats/devices'
import Conversions from './stats/conversions'

export default class Historical extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      pinned: true
    }
  }

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
        <div className={this.state.pinned ? 'sticky top-0 bg-gray-50 dark:bg-gray-850 z-10 pt-4 pb-2 shadow-sides-gray-50 dark:shadow-sides-gray-850' : 'pt-4 pb-2'}>
          <div className="w-full sm:flex justify-between items-center">
            <div className="w-full flex items-center">
              <SiteSwitcher site={this.props.site} loggedIn={this.props.loggedIn} />
              <CurrentVisitors timer={this.props.timer} site={this.props.site}  />
            </div>
            <div className='dark:text-gray-100 flex items-center'>
              <span title={this.state.pinned ? 'Prevent this menu from remaining on the screen as you scroll' : 'Allow this menu to remain on the screen as you scroll'}>
                <svg
                  style={{cursor: 'pointer', transform: `rotate(-${this.state.pinned ? 135 : 45}deg)`}}
                  onClick={() => this.setState({pinned: !this.state.pinned})}
                  height='20px'
                  width='20px'
                  fill={this.state.pinned ? 'currentColor' : 'transparent'}
                  stroke="currentColor"
                  viewBox="0 0 100 100"
                  >
                  <path stroke-width="8" d="M52.11,91.29c-0.48,0.48-1.26,0.48-1.74,0L31.28,72.19L9.27,94.21c-0.17,0.17-0.39,0.29-0.63,0.34l-2.17,0.43  c-0.86,0.17-1.62-0.59-1.44-1.44l0.43-2.17c0.05-0.24,0.16-0.46,0.34-0.63l22.01-22.01L8.71,49.62c-0.48-0.48-0.48-1.26,0-1.74  c4.11-4.11,10.39-4.68,15.12-1.76l35.03-27.74c-1.66-4.38-0.73-9.51,2.79-13.03c0.48-0.48,1.26-0.48,1.74,0l31.25,31.25  c0.48,0.48,0.48,1.26,0,1.74c-3.52,3.52-8.65,4.45-13.03,2.79L53.87,76.16C56.79,80.9,56.22,87.18,52.11,91.29z" />
                </svg>
              </span>
              <Datepicker site={this.props.site} query={this.props.query} />
            </div>
          </div>
          <Filters query={this.props.query} history={this.props.history} />
        </div>
        <VisitorGraph site={this.props.site} query={this.props.query} />
        <div className="w-full block md:flex items-start justify-between">
          <Sources site={this.props.site} query={this.props.query} />
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
