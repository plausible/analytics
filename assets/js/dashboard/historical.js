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

class SiteSwitcher extends React.Component {
  constructor() {
    super()
    this.state = {open: false}
  }

  toggle() {
    this.setState({open: !this.state.open})
  }

  render() {
    const extraClass = this.state.open ? "transform opacity-100 scale-100 transition ease-in duration-75" : "transform opacity-0 scale-95 transition ease-out duration-100"

    return (
      <div className="relative inline-block text-left z-10 mr-8">
        <button onClick={this.toggle.bind(this)} className="inline-flex items-center text-lg w-full rounded-md py-2 leading-5 font-medium text-gray-700 hover:text-gray-500 focus:outline-none focus:border-blue-300 focus:shadow-outline-blue transition ease-in-out duration-150" id="options-menu" aria-haspopup="true" aria-expanded="true">

          <img src={`https://icons.duckduckgo.com/ip3/${this.props.site.domain}.ico`} className="inline w-4 mr-2 align-middle" />
          {this.props.site.domain}
          <svg className="-mr-1 ml-2 h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
          </svg>
        </button>

        <div className={'origin-top-left absolute left-0 mt-2 w-56 rounded-md shadow-lg ' + extraClass}>
          <div className="rounded-md bg-white shadow-xs" role="menu" aria-orientation="vertical" aria-labelledby="options-menu">
            <div className="py-1">
              <a href="#" className="block px-4 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900" role="menuitem">Settings</a>
            </div>
            <div className="border-t border-gray-100"></div>
            <div className="py-1">
              <a href="#" className="block px-4 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900" role="menuitem">gigride.live</a>
              <a href="#" className="block px-4 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900" role="menuitem">did.app</a>
            </div>
          </div>
        </div>
      </div>
    )
  }
}

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
            <SiteSwitcher site={this.props.site}  />
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
