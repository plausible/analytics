import React from 'react';
import Datamap from 'datamaps'

import Bar from './bar'
import MoreLink from './more-link'
import * as api from '../api'

export default class Countries extends React.Component {
  constructor(props) {
    super(props)
    this.resizeMap = this.resizeMap.bind(this)
    this.state = {
      loading: true
    }
  }

  componentDidMount() {
    this.fetchCountries()
    window.addEventListener('resize', this.resizeMap);
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

  fetchCountries() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/countries`, this.props.query)
      .then((res) => this.setState({loading: false, countries: res}))
      .then(() => this.drawMap())
  }

  resizeMap() {
    this.map && this.map.resize()
  }

  drawMap() {
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

  render() {
    if (this.state.loading) {
      return (
        <div className="stats-item bg-white shadow-xl rounded p-4" style={{height: '436px'}}>
          <div className="loading my-32 mx-auto"><div></div></div>
        </div>
      )
    } else if (this.state.countries) {
      return (
        <div className="stats-item bg-white shadow-xl rounded p-4" style={{height: '436px'}}>
          <h3>Countries</h3>
          <div className="mt-6 mx-auto" style={{width: '100%', maxWidth: '475px', height: '320px'}} id="map-container"></div>
          <MoreLink site={this.props.site} list={this.state.countries} endpoint="countries" />
        </div>
      )
    }
  }
}
