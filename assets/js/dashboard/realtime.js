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

export default class Stats extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      pinned: (window.localStorage['pinned__realtime'] || 'true') === 'true',
      stuck: false
    }
  }

  componentDidMount() {
    this.observer = new IntersectionObserver((entries) => {
      if (entries[0].intersectionRatio === 0)
        this.setState({stuck: true});
      else if (entries[0].intersectionRatio === 1)
        this.setState({stuck: false});
    }, {
      threshold: [0, 1]
    });

    this.observer.observe(document.querySelector("#stats-container-top"));
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevState.pinned !== this.state.pinned) {
      window.localStorage['pinned__realtime'] = this.state.pinned;
    }
  }

  componentWillUnmount() {
    this.observer.unobserve(document.querySelector("#stats-container-top"));
  }

  renderConversions() {
    if (this.props.site.hasGoals) {
      return (
        <div className="w-full block md:flex items-start justify-between mt-6">
          <Conversions site={this.props.site} query={this.props.query} title="Goal Conversions (last 30 min)" />
        </div>
      )
    }
  }

  render() {
    return (
      <div className="mb-12">
        <div id="stats-container-top"></div>
        <div className={`${this.state.pinned ? 'sticky top-0 bg-gray-50 dark:bg-gray-850 pt-4 pb-2 z-9' : 'pt-4 pb-2'} ${this.state.pinned && this.state.stuck ? 'z-10 fullwidth-shadow' : ''}`}>
          <div className="w-full sm:flex justify-between items-center">
            <div className="w-full flex items-center">
              <SiteSwitcher site={this.props.site} loggedIn={this.props.loggedIn} />
            </div>
            <div className='dark:text-gray-100 flex items-center justify-end'>
              <Datepicker site={this.props.site} query={this.props.query} />
              <span title={this.state.pinned ? 'Prevent this menu from remaining on the screen as you scroll' : 'Allow this menu to remain on the screen as you scroll'}>
                <svg
                  style={{cursor: 'pointer', transform: `rotate(-${this.state.pinned ? 135 : 45}deg)`}}
                  onClick={() => {
                    this.setState(
                      (state) => ({pinned: !state.pinned})
                    );
                  }}
                  height='20px'
                  width='20px'
                  fill={this.state.pinned ? 'currentColor' : 'transparent'}
                  stroke="currentColor"
                  viewBox="0 0 100 100"
                  >
                  <path stroke-width="8" d="M52.11,91.29c-0.48,0.48-1.26,0.48-1.74,0L31.28,72.19L9.27,94.21c-0.17,0.17-0.39,0.29-0.63,0.34l-2.17,0.43  c-0.86,0.17-1.62-0.59-1.44-1.44l0.43-2.17c0.05-0.24,0.16-0.46,0.34-0.63l22.01-22.01L8.71,49.62c-0.48-0.48-0.48-1.26,0-1.74  c4.11-4.11,10.39-4.68,15.12-1.76l35.03-27.74c-1.66-4.38-0.73-9.51,2.79-13.03c0.48-0.48,1.26-0.48,1.74,0l31.25,31.25  c0.48,0.48,0.48,1.26,0,1.74c-3.52,3.52-8.65,4.45-13.03,2.79L53.87,76.16C56.79,80.9,56.22,87.18,52.11,91.29z" />
                </svg>
              </span>
            </div>
          </div>
          <Filters query={this.props.query} history={this.props.history} />
        </div>
        <VisitorGraph site={this.props.site} query={this.props.query} timer={this.props.timer} />
        <div className="w-full block md:flex items-start justify-between">
          <Sources site={this.props.site} query={this.props.query} timer={this.props.timer} />
          <Pages site={this.props.site} query={this.props.query} timer={this.props.timer} />
        </div>
        <div className="w-full block md:flex items-start justify-between">
          <Countries site={this.props.site} query={this.props.query} timer={this.props.timer} />
          <Devices site={this.props.site} query={this.props.query} timer={this.props.timer} />
        </div>

        { this.renderConversions() }
      </div>
    )
  }
}
