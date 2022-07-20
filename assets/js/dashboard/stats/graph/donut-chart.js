import React, { useState, useEffect, useRef } from 'react';
import { Link } from 'react-router-dom'

import Chart from 'chart.js/auto';
import FadeIn from '../../fade-in'
import MoreLink from '../more-link'
import numberFormatter from '../../util/number-formatter'
import Bar from '../bar'
import LazyLoader from '../../components/lazy-loader'


const faded = false;

class DonutChart extends React.Component {

  constructor(props) {
    super(props);
    this.regenerateChart = this.regenerateChart.bind(this);
    this.state = { };
  }

  regenerateChart() {
    const { chartData, valueKey, renderColor } = this.props
    const chartEl = document.getElementById("donut-canvas")
    this.ctx = chartEl.getContext('2d');

    return new Chart(this.ctx, {
      type: 'doughnut',
      data: {
        labels: chartData.map(listItem => listItem.name),
        datasets: [{
          data: chartData.map(listItem => listItem[valueKey]),
          percentages: chartData.map(listItem => listItem.percentage),
          borderColor: faded ? chartData.map(listItem => renderColor(listItem, 1.1)) : 'white',
          backgroundColor: chartData.map(listItem => renderColor(listItem, faded ? 1.45 : 1)),
          hoverOffset: 4
        }]
      },
      options: {
        layout: {
            padding: 10  // allow room for hover expansion
        },
        plugins: {
          legend: false,
          tooltip: {
            callbacks: {
              title() {
                return '';
              },
              label(tooltipItem) {
                let dataLabel = ' ' + tooltipItem.label
                dataLabel += ': ' + tooltipItem.formattedValue
                dataLabel += ' ' + valueKey;  // FIXME "1 visitors"
                dataLabel += ' (' + tooltipItem.dataset.percentages[tooltipItem.dataIndex] + '%)';
                return dataLabel;
              }
            }
          }
        }
      }
    });
  }

  componentDidMount() {
    if (this.props.chartData) {
      this.chart = this.regenerateChart();
    }
  }

  componentDidUpdate(prevProps) {
    const { chartData, darkTheme } = this.props;

    if (chartData && (
      chartData !== prevProps.chartData ||
      darkTheme !== prevProps.darkTheme
    )) {
      if (this.chart) {
        this.chart.destroy();
      }
      this.chart = this.regenerateChart();
      this.chart.update();
    }

    if (!chartData && this.chart) {
      this.chart.destroy();
    }
  }

  render() {
    return (
      <canvas id="donut-canvas" className="donut" width="180" height="180"></canvas>
    )
  }
}

export default function DonutChartTab(props) {
  const [state, setState] = useState({loading: true, segments: null})
  const valueKey = props.valueKey || 'visitors'
  const showConversionRate = !!props.query.filters.goal
  const prevQuery = useRef();

  function fetchData() {
    if (typeof(prevQuery.current) === 'undefined' || prevQuery.current !== props.query) {
      prevQuery.current = props.query;
      setState({loading: true, segments: null})
      props.fetchData()
        .then((res) => setState({loading: false, segments: res}))
    }
  }

  function onVisible() {
    fetchData()
    if (props.timer) props.timer.onTick(fetchData)
  }

  function label() {
    if (props.query.period === 'realtime') {
      return 'Current visitors'
    }

    if (showConversionRate) {
      return 'Conversions'
    }

    return props.valueLabel || 'Visitors'
  }

  useEffect(fetchData, [props.query]);

  function renderListItem(listItem) {
    const query = new URLSearchParams(window.location.search)

    Object.entries(props.filter).forEach((([key, valueKey]) => {
      query.set(key, listItem[valueKey])
    }))

    const maxWidthDeduction =  showConversionRate ? "10rem" : "5rem"
    const noop = () => {}

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={listItem.name}>
        <Bar
          count={listItem[valueKey]}
          all={state.segments}
          maxWidthDeduction={maxWidthDeduction}
          plot={valueKey}
        >
          <span className="flex px-2 py-1.5 group dark:text-gray-300 relative z-9 break-all" tooltip={props.tooltipText && props.tooltipText(listItem)}>
            <div className="donut-legend-color-circle" style={{color: faded ? props.renderColor(listItem) : 'white', borderColor: faded ? props.renderColor(listItem) : 'white', backgroundColor: props.renderColor(listItem, faded ? 1.6 : 1) }}>
              {props.renderIcon && props.renderIcon(listItem)}
            </div>
            <Link onClick={props.onClick || noop} className="md:truncate block hover:underline" to={{search: query.toString()}}>
              {listItem.name}
            </Link>
	  </span>
        </Bar>
        <span className="font-medium dark:text-gray-200 w-20 text-right" tooltip={listItem[valueKey]}>
          {numberFormatter(listItem[valueKey])}
        </span>
        {showConversionRate && <span className="font-medium dark:text-gray-200 w-20 text-right">{listItem.conversion_rate}%</span>}
      </div>
    )
  }

  function render() {
    if (state.segments && state.segments.length > 0) {
      return (
        <>
          <DonutChart chartData={state.segments} valueKey={valueKey} renderColor={props.renderColor} />
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>{ props.keyLabel }</span>
            <span className="text-right">
              <span className="inline-block w-30">{label()}</span>
              {showConversionRate && <span className="inline-block w-20">CR</span>}
            </span>
          </div>
          { state.segments && state.segments.map(renderListItem) }
        </>
      )
    }

    return <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">No data yet</div>
  }

  return (
    <LazyLoader onVisible={onVisible} className="flex flex-col flex-grow">
      { state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
      <FadeIn show={!state.loading} className="flex-grow">
        { render() }
      </FadeIn>
      {props.detailsLink && !state.loading && <MoreLink url={props.detailsLink} segments={state.segments} />}
    </LazyLoader>
  )
}
