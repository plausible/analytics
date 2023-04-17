import React from 'react';
import Chart from 'chart.js/auto';

import * as api from '../api'
import LazyLoader from '../components/lazy-loader'

const FUNNEL_ID = 1


export default class Funnel extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
    this.onVisible = this.onVisible.bind(this)
    this.fetchFunnel = this.fetchFunnel.bind(this)
  }

  onVisible() {
    this.fetchFunnel()
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.fetchFunnel()
    }
  }


  fetchFunnel() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/funnels/${FUNNEL_ID}`, this.props.query)
      .then((res) => this.setState({loading: false, funnel: res}))
      .then(this.initialiseChart)
  }

  initialiseChart() {
    const ctx = document.getElementById('funnel').getContext('2d')

    var gradient = ctx.createLinearGradient(0, 0, 0, 300);
    gradient.addColorStop(1, 'rgba(101,116,205, 0.3)');
    gradient.addColorStop(0, 'rgba(101,116,205, 0)');

    const data = {
      labels: ['1. Visit /blog/**', '2. Visit /register', '3. Signup', '4. Go to moon', '5. Turn it up to 11'],
      datasets: [{
        label: 'My First Dataset',
        data: [100, 80, 20, 4, 1],
        backgroundColor: [gradient],
        borderColor: ['rgba(101,116,205)'],
        borderWidth: 1,
        borderRadius: 8
      }]
    };

    const config = {
      type: 'bar',
      data: data,
      options: {
        responsive: true,
        layout: {
          padding: {left: 0, right: 0}
        },
        plugins: {
          legend: {
            display: false,
          },
        },
        scales: {
          y: {display: false, border: {display: false}},
          x: {display: true, border: {display: false}, grid: {drawOnChartArea: false, drawTicks: false}, ticks: {font: {weight: 'bold', size: 14}, color: 'rgb(75, 85, 99)'}}
        }
      },
    };

    new Chart(ctx, config);
  }

  renderInner() {
    if (this.state.loading) {
      return <div className="mx-auto my-2 loading"><div></div></div>
    } else if (this.state.funnel) {
      return (
        <React.Fragment>
          <h3 className="font-bold dark:text-gray-100">Signup funnel</h3>
          <canvas className="mt-8" id="funnel" height="100px"></canvas>
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <LazyLoader className="w-full p-4 bg-white rounded shadow-xl dark:bg-gray-825" style={{minHeight: '132px', height: this.state.prevHeight ?? 'auto'}} onVisible={this.onVisible} ref={this.htmlNode}>
        { this.renderInner() }
      </LazyLoader>
    )
  }
}
