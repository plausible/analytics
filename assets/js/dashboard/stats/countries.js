import React from 'react';
import Datamap from 'datamaps'
import { withRouter } from 'react-router-dom'

import numberFormatter from '../number-formatter'
import FadeIn from '../fade-in'
import Bar from './bar'
import MoreLink from './more-link'
import * as api from '../api'
import { navigateToQuery } from '../query'
import { withThemeConsumer } from '../theme-consumer-hoc';
class Countries extends React.Component {
  constructor(props) {
    super(props)
    this.resizeMap = this.resizeMap.bind(this)
    this.drawMap = this.drawMap.bind(this)
    this.getDataset = this.getDataset.bind(this)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchCountries().then(this.drawMap.bind(this))
    window.addEventListener('resize', this.resizeMap);
    if (this.props.timer) this.props.timer.onTick(this.updateCountries.bind(this))
  }

  componentWillUnmount() {
    window.removeEventListener('resize', this.resizeMap);
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, countries: null})
      this.fetchCountries().then(this.drawMap.bind(this))
    }

    if (this.props.darkTheme !== prevProps.darkTheme) {
      if (document.getElementById('map-container')) {
        document.getElementById('map-container').removeChild(document.querySelector('.datamaps-hoverover'));
        document.getElementById('map-container').removeChild(document.querySelector('.datamap'));
      }
      this.drawMap();
    }
  }

  getDataset() {
    var dataset = {};

    var onlyValues = this.state.countries.map(function(obj){ return obj.count });
    var maxValue = Math.max.apply(null, onlyValues);

    var paletteScale = d3.scale.linear()
      .domain([0,maxValue])
      .range([
        this.props.darkTheme ? "#2e3954" : "#f3ebff",
        this.props.darkTheme ? "#6366f1" : "#a779e9"
      ]);

    this.state.countries.forEach(function(item){
      dataset[item.name] = {numberOfThings: item.count, fillColor: paletteScale(item.count)};
    });

    return dataset
  }

  updateCountries() {
    this.fetchCountries().then(() => {
      this.map.updateChoropleth(this.getDataset(), {reset: true})
    })
  }

  fetchCountries() {
    return api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/countries`, this.props.query)
      .then((res) => this.setState({loading: false, countries: res}))
  }

  resizeMap() {
    this.map && this.map.resize()
  }

  drawMap() {
    var dataset = this.getDataset();
    const label = this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
    const defaultFill = this.props.darkTheme ? '#2d3747' : '#f8fafc'
    const highlightFill = this.props.darkTheme ? '#374151' : '#F5F5F5'
    const borderColor = this.props.darkTheme ? '#1f2937' : '#dae1e7'
    const highlightBorderColor = this.props.darkTheme ? '#4f46e5' : '#a779e9'

    this.map = new Datamap({
      element: document.getElementById('map-container'),
      responsive: true,
      projection: 'mercator',
      fills: { defaultFill },
      data: dataset,
      geographyConfig: {
        borderColor,
        highlightBorderWidth: 2,
        highlightFillColor: function(geo) {
          return geo['fillColor'] || highlightFill;
        },
        highlightBorderColor,
        popupTemplate: function(geo, data) {
          if (!data) { return ; }
          const pluralizedLabel = data.numberOfThings === 1 ? label.slice(0, -1) : label
          return ['<div class="hoverinfo dark:bg-gray-800 dark:shadow-gray-850 dark:border-gray-850 dark:text-gray-200">',
            '<strong>', geo.properties.name, '</strong>',
            '<br><strong class="dark:text-indigo-400">', numberFormatter(data.numberOfThings), '</strong> ' + pluralizedLabel,
            '</div>'].join('');
        }
      },
      done: (datamap) => {
        datamap.svg.selectAll('.datamaps-subunit').on('click', (geography) => {
          navigateToQuery(
            this.props.history,
            this.props.query,
            {
              country: geography.id
            }
          )
        })
      }
    });
  }

  renderBody() {
    if (this.state.countries) {
      return (
        <React.Fragment>
          <h3 className="font-bold dark:text-gray-100">Countries</h3>
          <div className="mt-6 mx-auto" style={{width: '100%', maxWidth: '475px', height: '320px'}} id="map-container"></div>
          <MoreLink site={this.props.site} list={this.state.countries} endpoint="countries" />
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <div className="stats-item relative bg-white dark:bg-gray-825 shadow-xl rounded p-4" style={{height: '436px'}}>
        { this.state.loading && <div className="loading my-32 mx-auto"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderBody() }
        </FadeIn>
      </div>
    )
  }
}

export default withRouter(withThemeConsumer(Countries))
