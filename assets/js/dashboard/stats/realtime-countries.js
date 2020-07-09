import React from 'react';
import Datamap from 'datamaps'

import FadeIn from '../fade-in'
import numberFormatter from '../number-formatter'
import Bar from './bar'
import MoreLink from './more-link'
import * as api from '../api'

export default class Countries extends React.Component {
  constructor(props) {
    super(props)
    this.resizeMap = this.resizeMap.bind(this)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchCountries().then(this.drawMap.bind(this))
    window.addEventListener('resize', this.resizeMap);
    if (this.props.timer) this.props.timer.addEventListener('tick', this.updateCountries.bind(this))
  }

  componentWillUnmount() {
    window.removeEventListener('resize', this.resizeMap);
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, countries: null})
      this.fetchCountries()
    }
  }

  getDataset() {
    var dataset = {};

    var onlyValues = this.state.countries.map(function(obj){ return obj.count });
    var minValue = Math.min.apply(null, onlyValues),
      maxValue = Math.max.apply(null, onlyValues);

    var paletteScale = d3.scale.linear()
      .domain([minValue,maxValue])
      .range(["#f3ebff","#a779e9"]);

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

    this.map = new Datamap({
      element: document.getElementById('map-container'),
      responsive: true,
      projection: 'mercator',
      fills: { defaultFill: '#f8fafc' },
      data: dataset,
      geographyConfig: {
        borderColor: '#dae1e7',
        highlightBorderWidth: 2,
        highlightFillColor: function(geo) {
          return geo['fillColor'] || '#F5F5F5';
        },
        highlightBorderColor: '#a779e9',
        popupTemplate: function(geo, data) {
          if (!data) { return ; }
          return ['<div class="hoverinfo">',
            '<strong>', geo.properties.name, '</strong>',
            '<br><strong>', data.numberOfThings, '</strong> Visitors',
            '</div>'].join('');
        }
      }
    });
  }

  renderCountry(country) {
    return (
      <div className="flex items-center justify-between my-1 text-sm" key={country.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={country.count} all={this.state.countries} bg="bg-purple-50" />
          <span className="block px-2" style={{marginTop: '-26px'}}>
            { country.full_country_name }
          </span>
        </div>
        <span className="font-medium">{numberFormatter(country.count)}</span>
      </div>
    )
  }

  renderList() {
    if (this.state.countries.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>Country</span>
            <span>Visitors</span>
          </div>

          {this.state.countries.slice(0, 10).map(this.renderCountry.bind(this))}
        </React.Fragment>
      )
    } else {
      return <div className="text-center mt-44 font-medium text-gray-500">No data yet</div>
    }
  }

  renderBody() {
    if (this.state.countries) {
      return (
        <div className="flex justify-between">
          <div style={{width: '100%', maxWidth: '640px', marginTop: '-110px'}} id="map-container"></div>
          <div className="flex-1 pl-4">
            { this.renderList() }
          </div>
        </div>
      )
    }
  }

  render() {
    return (
      <div className="w-full mt-6 relative bg-white shadow-xl rounded p-4" style={{height: '460px'}}>
        { this.state.loading && <div className="loading my-32 mx-auto"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          <h3 className="font-bold absolute">Countries</h3>
          { this.renderBody() }
        </FadeIn>
      </div>
    )
  }
}
