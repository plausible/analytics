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

  formatDataLabel(visitors, ctx) {
    if (ctx.dataset.label === 'Visitors') {
      const total = this.state.funnel.steps[0].visitors
      const percentage = (visitors / total) * 100
      return `${percentage}%\n${visitors} Visitors`
    } else {
      return null
    }
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
    const labels = this.state.funnel.steps.map((step, i) => `${i + 1}. ${step.label}`);
    const stepData = this.state.funnel.steps.map(step => step.visitors)
    const dropOffData = this.state.funnel.steps.map((step, i) => {
      const thisVisitors = step.visitors
      const prevEntry = this.state.funnel.steps[i - 1]
      if (prevEntry) {
        return prevEntry.visitors - thisVisitors
      } else {
        return 0
      }
    })

    const ctx = document.getElementById('funnel').getContext('2d')

    var gradient = ctx.createLinearGradient(0, 0, 0, 300);
    gradient.addColorStop(1, 'rgba(101,116,205, 0.3)');
    gradient.addColorStop(0, 'rgba(101,116,205, 0)');

    const data = {
      labels: labels,
      datasets: [
        {
          label: 'Visitors',
          data: stepData,
          backgroundColor: ['rgb(99, 102, 241)'],
          borderRadius: 4,
          stack: 'Stack 0',
        },
        {
          label: 'Dropoff',
          data: dropOffData,
          backgroundColor: ['rgb(224, 231, 255)'],
          borderRadius: 4,
          stack: 'Stack 0',
        }
      ],
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
            formatter: this.formatDataLabel.bind(this),
            anchor: 'end',
            backgroundColor: 'rgba(25, 30, 56)',
            color: 'rgb(243, 244, 246)',
            borderRadius: 4,
            font: {size: 14, weight: 'bold'},
            textAlign: 'center',
            padding: {top: 4, bottom: 4, right: 8, left: 8}
          }
        },
        scales: {
          y: { display: false},
          x: { position: 'top', display: true, border: { display: false }, grid: {drawBorder: false, display: false}, ticks: {padding: 24, font: { weight: 'bold', size: 14 }, color: 'rgb(17, 24, 39)'}}
        }
      },
    };

    this.chart = new Chart(ctx, config);
  }

  renderInner() {
    if (this.state.loading) {
      return <div className="mx-auto loading pt-44"><div></div></div>
    } else if (this.state.funnel) {
      const firstStep = this.state.funnel.steps[0].visitors
      const lastStep = this.state.funnel.steps[this.state.funnel.steps.length - 1].visitors
      const conversionRate = (lastStep / firstStep) * 100

      return (
        <React.Fragment>
          <div className="flex justify-between w-full">
            <h3 className="font-bold dark:text-gray-100">{this.state.funnel.name}</h3>
            {this.props.tabs}
          </div>
          <p className="mt-1 text-gray-500 text-sm">{this.state.funnel.steps.length}-step funnel • {conversionRate}% conversion rate</p>
          <canvas className="py-4" id="funnel" height="100px"></canvas>
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <LazyLoader style={{minHeight: '400px'}} onVisible={this.onVisible} ref={this.htmlNode}>
        {this.renderInner()}
      </LazyLoader>
    )
  }
}
