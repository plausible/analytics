import React, { useEffect, useState, useRef } from 'react'
import Chart from 'chart.js/auto'
import ChartDataLabels from 'chartjs-plugin-datalabels'
import numberFormatter from '../../util/number-formatter'

import RocketIcon from '../modals/rocket-icon'

import * as api from '../../api'
import LazyLoader from '../../components/lazy-loader'

Chart.register(ChartDataLabels)

export default function Funnel(props) {
  const [loading, setLoading] = useState(true)
  const [visible, setVisible] = useState(false)
  const [error, setError] = useState(undefined)
  const [funnel, setFunnel] = useState(null)
  const chartRef = useRef(null)
  const canvasRef = useRef(null)

  useEffect(() => {
    if (visible) {
      setLoading(true)
      fetchFunnel()
        .then((res) => {
          setFunnel(res)
          setError(undefined)
        })
        .catch((error) => {
          setError(error)
        })
        .finally(() => {
          setLoading(false)
        })

      return () => {
        console.info('cleanup')
        if (chartRef.current) {
          chartRef.current.destroy()
        }
      }
    }
  }, [props.query, props.funnelName, visible])

  useEffect(() => {
    if (canvasRef.current && funnel && visible) {
      initialiseChart()
    }
  }, [funnel, visible])

  const formatDataLabel = (visitors, ctx) => {
    if (ctx.dataset.label === 'Visitors') {
      const conversionRate = funnel.steps[ctx.dataIndex].conversion_rate
      return `${conversionRate}%\n${numberFormatter(visitors)} Visitors`
    } else {
      return null
    }
  }

  const getFunnel = () => {
    return props.site.funnels.find((funnel) => funnel.name === props.funnelName)
  }

  const fetchFunnel = async () => {
    const funnelMeta = getFunnel()
    if (typeof funnelMeta === 'undefined') {
      setError({ message: "Failed to locate funnel" })
    } else {
      return api.get(`/api/stats/${encodeURIComponent(props.site.domain)}/funnels/${funnelMeta.id}`, props.query)
    }
  }

  const initialiseChart = () => {
    console.info('canvasRef', canvasRef)
    if (chartRef.current) {
      chartRef.current.destroy()
    }
    const labels = funnel.steps.map((step, i) => `${i + 1}. ${step.label}`)
    const stepData = funnel.steps.map((step) => step.visitors)

    const dropOffData = funnel.steps.map((step) => step.dropoff)

    const ctx = canvasRef.current.getContext("2d")
    console.info('ctx canvasRef', canvasRef)
    console.info('ctx', ctx)

    var gradient = ctx.createLinearGradient(0, 0, 0, 300)
    gradient.addColorStop(1, 'rgba(101,116,205, 0.3)')
    gradient.addColorStop(0, 'rgba(101,116,205, 0)')

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
          backgroundColor: ['rgb(224, 231, 255)'], // TODO: support dark mode
          borderRadius: 4,
          stack: 'Stack 0',
        },
      ],
    }

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
            formatter: formatDataLabel,
            anchor: 'end',
            backgroundColor: 'rgba(25, 30, 56)',
            color: 'rgb(243, 244, 246)',
            borderRadius: 4,
            font: { size: 14, weight: 'bold' },
            textAlign: 'center',
            padding: { top: 4, bottom: 4, right: 8, left: 8 },
          },
        },
        scales: {
          y: { display: false },
          x: {
            position: 'top',
            display: true,
            border: { display: false },
            grid: { drawBorder: false, display: false },
            ticks: { padding: 24, font: { weight: 'bold', size: 14 }, color: 'rgb(17, 24, 39)' },
          },
        },
      },
    }

    chartRef.current = new Chart(ctx, config)
  }

  const header = () => {
    return (
      <div className="flex justify-between w-full">
        <h3 className="font-bold dark:text-gray-100">Funnel: {props.funnelName}</h3>
        {props.tabs}
      </div>
    )
  }

  const renderError = () => {
    if (error.payload && error.payload.level === 'normal') {
      return (
        <>
          {header()}
          <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">{error.message}</div>
        </>
      )
    } else {
      return (
        <>
          {header()}
          <div className="text-center text-gray-900 dark:text-gray-100 mt-16">
            <RocketIcon />
            <div className="text-lg font-bold">Oops! Something went wrong</div>
            <div className="text-lg">{error.message ? error.message : 'Failed to render funnel'}</div>
            <div className="text-xs mt-8">Please try refreshing your browser or selecting the funnel again.</div>
          </div>
        </>
      )
    }
  }

  const renderInner = () => {
    if (loading) {
      return <div className="mx-auto loading pt-44"><div></div></div>
    } else if (error) {
      return renderError()
    } else if (funnel) {
      const conversionRate = funnel.steps[funnel.steps.length - 1].conversion_rate

      return (
        <>
          {header()}
          <p className="mt-1 text-gray-500 text-sm">{funnel.steps.length}-step funnel • {conversionRate}% conversion rate</p>
        </>
      )
    }
  }

  return (
    <div style={{ minHeight: '400px' }}>
      <LazyLoader onVisible={() => setVisible(true)}>
        {renderInner()}
      </LazyLoader>
      <canvas className="py-4" id="funnel" ref={canvasRef}></canvas>
    </div>
  )
}
