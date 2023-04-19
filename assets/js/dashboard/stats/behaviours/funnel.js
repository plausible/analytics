import React from 'react';
import Chart from 'chart.js/auto';
import ChartDataLabels from 'chartjs-plugin-datalabels';
Chart.register(ChartDataLabels);

import * as api from '../../api'
import LazyLoader from '../../components/lazy-loader'



export default class Funnel extends React.Component {
  constructor(props) {
    super(props)
    this.state = { loading: true }
    this.onVisible = this.onVisible.bind(this)
    this.fetchFunnel = this.fetchFunnel.bind(this)
  }

  onVisible() {
    this.fetchFunnel()
  }

  componentDidUpdate(prevProps) {
    const queryChanged = this.props.query !== prevProps.query
    const funnelChanged = this.props.funnel !== prevProps.funnel

    if (queryChanged || funnelChanged) {
      this.setState({loading: true})
      this.fetchFunnel()
    }
  }

  formatDataLabel(visitors) {
    const total = this.state.funnel.steps[0].visitors
    const percentage = (visitors / total) * 100
    return `${visitors} Visitors (${percentage}%)`
  }

  fetchFunnel() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/funnels/${this.props.funnel.id}`, this.props.query)
      .then((res) => this.setState({ loading: false, funnel: res }))
      .then(this.initialiseChart.bind(this))
  }

  initialiseChart() {
    if (this.chart) {
      this.chart.destroy()
    }
    const labels = this.state.funnel.steps.map(step => step.label);
    const stepData = this.state.funnel.steps.map(step => step.visitors)
    const ctx = document.getElementById('funnel').getContext('2d')

    var gradient = ctx.createLinearGradient(0, 0, 0, 300);
    gradient.addColorStop(1, 'rgba(101,116,205, 0.3)');
    gradient.addColorStop(0, 'rgba(101,116,205, 0)');

    const data = {
      labels: labels,
      datasets: [{
        label: 'Visitors',
        data: stepData,
        backgroundColor: [gradient],
        borderColor: ['rgba(101,116,205)'],
        borderWidth: 1,
        borderSkipped: false,
        borderRadius: 4
      }]
    };

    const config = {
      plugins: [ChartDataLabels],
      type: 'bar',
      data: data,
      options: {
        responsive: true,
        barThickness: 120,
        plugins: {
          legend: {
            display: false,
          },
          datalabels: {
            formatter: this.formatDataLabel.bind(this)
          }
        },
        scales: {
          y: { display: false, border: { display: false } },
          x: { display: true, border: { display: false }, grid: { drawOnChartArea: false, drawTicks: false }, ticks: { font: { weight: 'bold', size: 14 }, color: 'rgb(75, 85, 99)' } }
        }
      },
    };

    this.chart = new Chart(ctx, config);
  }

  renderInner() {
    if (this.state.loading) {
      return <div className="mx-auto my-2 loading"><div></div></div>
    } else if (this.state.funnel) {
      const firstStep = this.state.funnel.steps[0].visitors
      const lastStep = this.state.funnel.steps[this.state.funnel.steps.length - 1].visitors
      const conversionRate = (lastStep / firstStep) * 100

      return (
        <React.Fragment>
          <h3 className="font-semibold dark:text-gray-100">{this.state.funnel.name}</h3>
          <p className="text-gray-600">{this.state.funnel.steps.length}-step funnel • {conversionRate}% conversion rate</p>
          <canvas className="mt-8" id="funnel" height="100px"></canvas>
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <LazyLoader className="mt-2" onVisible={this.onVisible} ref={this.htmlNode}>
        {this.renderInner()}
      </LazyLoader>
    )
  }
}
