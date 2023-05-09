import React from 'react';
import Chart from 'chart.js/auto';
import ChartDataLabels from 'chartjs-plugin-datalabels';
Chart.register(ChartDataLabels);

import RocketIcon from '../modals/rocket-icon'

import * as api from '../../api'
import LazyLoader from '../../components/lazy-loader'

export default class Funnel extends React.Component {
  constructor(props) {
    super(props)
    this.state = { loading: true, error: null }
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
      this.setState({ loading: true, error: null })
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
    if (this.props.funnel) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/funnels/${this.props.funnel.id}`, this.props.query)
        .then((res) => {
          this.setState({ loading: false, funnel: res, error: null })
        })
        .then(this.initialiseChart.bind(this))
        .catch((error) => {
          this.setState({ loading: false, error: error })
        })
    } else {
      this.setState({ loading: false, error: { message: "Failed to locate funnel" } })
    }
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
            font: { size: 14, weight: 'bold' },
            textAlign: 'center',
            padding: { top: 4, bottom: 4, right: 8, left: 8 }
          }
        },
        scales: {
          y: { display: false },
          x: { position: 'top', display: true, border: { display: false }, grid: { drawBorder: false, display: false }, ticks: { padding: 24, font: { weight: 'bold', size: 14 }, color: 'rgb(17, 24, 39)' } }
        }
      },
    };

    this.chart = new Chart(ctx, config);
  }

  tabs() {
    return (
      <div className="flex justify-between w-full">
        <h3 className="font-bold dark:text-gray-100">Funnels</h3>
        {this.props.tabs}
      </div>
    )
  }

  renderInner() {
    if (this.state.loading) {
      return <div className="mx-auto loading pt-44"><div></div></div>
    } else if (this.state.error) {
      if (this.state.error && this.state.error.payload.level === "normal") {
        return (<React.Fragment>
          {this.tabs()}
          <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">{this.state.error.message}</div>
        </React.Fragment>)
      } else {
        return (
          <React.Fragment>
            {this.tabs()}
            <div className="text-center text-gray-900 dark:text-gray-100 mt-16">
              <RocketIcon />
              <div className="text-lg font-bold">Oops! Something went wrong</div>
              <div className="text-lg">{this.state.error.message ? this.state.error.message : "Failed to render funnel"}</div>
              <div className="text-xs mt-8">Please try refreshing your browser and selecting the funnel again.</div>
            </div>
          </React.Fragment>
        )
      }
    } else if (this.state.funnel) {
      const firstStep = this.state.funnel.steps[0].visitors
      const lastStep = this.state.funnel.steps[this.state.funnel.steps.length - 1].visitors
      const conversionRate = (lastStep / firstStep) * 100

      return (
        <React.Fragment>
          {this.tabs()}
          <p className="mt-1 text-gray-500 text-sm">{this.state.funnel.steps.length}-step funnel • {conversionRate}% conversion rate</p>
          <canvas className="py-4" id="funnel" height="100px"></canvas>
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <LazyLoader style={{ minHeight: '400px' }} onVisible={this.onVisible} ref={this.htmlNode}>
        {this.renderInner()}
      </LazyLoader>
    )
  }
}
