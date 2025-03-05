import React, { useEffect, useState, useRef } from 'react';
import FlipMove from 'react-flip-move';
import Chart from 'chart.js/auto';
import FunnelTooltip from './funnel-tooltip';
import ChartDataLabels from 'chartjs-plugin-datalabels';
import { numberShortFormatter } from '../util/number-formatter';
import Bar from '../stats/bar';

import RocketIcon from '../stats/modals/rocket-icon';

import * as api from '../api';
import LazyLoader from '../components/lazy-loader';
import { useQueryContext } from '../query-context';
import { useSiteContext } from '../site-context';


export default function Funnel({ funnelName, tabs }) {
  const site = useSiteContext();
  const { query } = useQueryContext();
  const [loading, setLoading] = useState(true)
  const [visible, setVisible] = useState(false)
  const [error, setError] = useState(undefined)
  const [funnel, setFunnel] = useState(null)
  const [isSmallScreen, setSmallScreen] = useState(false)
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
        if (chartRef.current) {
          chartRef.current.destroy()
        }
      }
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query, funnelName, visible, isSmallScreen])

  useEffect(() => {
    if (canvasRef.current && funnel && visible && !isSmallScreen) {
      initialiseChart()
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [funnel, visible])

  useEffect(() => {
    const mediaQuery = window.matchMedia('(max-width: 768px)')
    setSmallScreen(mediaQuery.matches)
    const handleScreenChange = (e) => {
      setSmallScreen(e.matches);
    }
    mediaQuery.addEventListener("change", handleScreenChange);
    return () => {
      mediaQuery.removeEventListener("change", handleScreenChange)
    }
  }, [])

  const isDarkMode = () => {
    return document.querySelector('html').classList.contains('dark') || false
  }

  const getPalette = () => {
    if (isDarkMode()) {
      return {
        dataLabelBackground: 'rgba(25, 30, 56, 0.97)',
        dataLabelTextColor: 'rgb(243, 244, 246)',
        visitorsBackground: 'rgb(99, 102, 241)',
        dropoffBackground: '#2F3949',
        dropoffStripes: 'rgb(25, 30, 56)',
        stepNameLegendColor: 'rgb(228, 228, 231)',
        visitorsLegendClass: 'bg-indigo-500',
        dropoffLegendClass: 'bg-gray-600',
        smallBarClass: 'bg-indigo-500'
      }
    } else {
      return {
        dataLabelBackground: 'rgba(25, 30, 56, 0.97)',
        dataLabelTextColor: 'rgb(243, 244, 246)',
        visitorsBackground: 'rgb(99, 102, 241)',
        dropoffBackground: 'rgb(224, 231, 255)',
        dropoffStripes: 'rgb(255, 255, 255)',
        stepNameLegendColor: 'rgb(12, 24, 39)',
        visitorsLegendClass: 'bg-indigo-500',
        dropoffLegendClass: 'bg-indigo-100',
        smallBarClass: 'bg-indigo-300'
      }
    }
  }

  const formatDataLabel = (visitors, ctx) => {
    if (ctx.dataset.label === 'Visitors') {
      const conversionRate = funnel.steps[ctx.dataIndex].conversion_rate
      return `${conversionRate}% \n(${numberShortFormatter(visitors)} Visitors)`
    } else {
      return null
    }
  }

  const calcOffset = (ctx) => {
    const conversionRate = parseFloat(funnel.steps[ctx.dataIndex].conversion_rate)
    if (conversionRate > 90) {
      return -64
    } else if (conversionRate > 20) {
      return -28
    } else {
      return 8
    }
  }

  const getFunnel = () => {
    return site.funnels.find((funnel) => funnel.name === funnelName)
  }

  const fetchFunnel = async () => {
    const funnelMeta = getFunnel()
    if (typeof funnelMeta === 'undefined') {
      throw new Error('Could not fetch the funnel. Perhaps it was deleted?')
    } else {
      return api.get(site, `/api/stats/${encodeURIComponent(site.domain)}/funnels/${funnelMeta.id}`, query)
    }
  }

  const initialiseChart = () => {
    if (chartRef.current) {
      chartRef.current.destroy()
    }

    const palette = getPalette()

    const createDiagonalPattern = (color1, color2) => {
      // create a 10x10 px canvas for the pattern's base shape
      let shape = document.createElement('canvas')
      shape.width = 10
      shape.height = 10
      let c = shape.getContext('2d')

      c.fillStyle = color1
      c.strokeStyle = color2
      c.fillRect(0, 0, shape.width, shape.height);

      c.beginPath()
      c.moveTo(2, 0)
      c.lineTo(10, 8)
      c.stroke()

      c.beginPath()
      c.moveTo(0, 8)
      c.lineTo(2, 10)
      c.stroke()

      return c.createPattern(shape, 'repeat')
    }

    const labels = funnel.steps.map((step) => step.label)
    const stepData = funnel.steps.map((step) => step.visitors)

    const dropOffData = funnel.steps.map((step) => step.dropoff)
    const ctx = canvasRef.current.getContext("2d")

    const calcBarThickness = (ctx) => {
      if (ctx.dataset.data.length <= 3) {
        return 160
      } else {
        return Math.floor(650 / ctx.dataset.data.length)
      }
    }

    // passing those verbatim to make sure canvas rendering picks them up
    var fontFamily = 'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"'

    var gradient = ctx.createLinearGradient(900, 0, 900, 900);
    gradient.addColorStop(1, palette.dropoffBackground);
    gradient.addColorStop(0, palette.visitorsBackground);

    const data = {
      labels: labels,
      datasets: [
        {
          label: 'Visitors',
          data: stepData,
          backgroundColor: gradient,
          hoverBackgroundColor: gradient,
          borderRadius: 4,
          stack: 'Stack 0',
        },
        {
          label: 'Dropoff',
          data: dropOffData,
          backgroundColor: createDiagonalPattern(palette.dropoffBackground, palette.dropoffStripes),
          hoverBackgroundColor: palette.dropoffBackground,
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
        barThickness: calcBarThickness,
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            enabled: false,
            mode: 'index',
            intersect: true,
            position: 'average',
            external: FunnelTooltip(palette, funnel)
          },
          datalabels: {
            formatter: formatDataLabel,
            anchor: 'end',
            align: 'end',
            offset: calcOffset,
            backgroundColor: palette.dataLabelBackground,
            color: palette.dataLabelTextColor,
            borderRadius: 4,
            clip: true,
            font: { size: 12, weight: 'normal', lineHeight: 1.6, family: fontFamily },
            textAlign: 'center',
            padding: { top: 8, bottom: 8, right: 8, left: 8 },
          },
        },
        scales: {
          y: { display: false },
          x: {
            position: 'bottom',
            display: true,
            border: { display: false },
            grid: { drawBorder: false, display: false },
            ticks: {
              padding: 8,
              font: { weight: 'bold', family: fontFamily, size: 14 },
              color: palette.stepNameLegendColor
            },
          },
        },
      },
    }

    chartRef.current = new Chart(ctx, config)
  }

  const header = () => {
    return (
      <div className="flex justify-between w-full">
        <h4 className="mt-2 text-sm dark:text-gray-100">{funnelName}</h4>
        {tabs}
      </div>
    )
  }

  const renderError = () => {
    if (error.name === 'AbortError') return
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
        <div className="mb-8">
          {header()}
          <p className="mt-1 text-gray-500 text-sm">{funnel.steps.length}-step funnel • {conversionRate}% conversion rate</p>
          {isSmallScreen && <div className="mt-4">{renderBars(funnel)}</div>}
        </div>
      )
    }
  }

  const renderBar = (step) => {
    const palette = getPalette()

    return (
      <>
        <div className="flex items-center justify-between my-1 text-sm">
          <Bar
            count={step.visitors}
            all={funnel.steps}
            bg={palette.smallBarClass}
            maxWidthDeduction={"5rem"}
            plot={'visitors'}
          >

            <span className="flex px-2 py-1.5 group dark:text-gray-100 relative z-9 break-all">
              {step.label}
            </span>
          </Bar>

          <span className="font-medium dark:text-gray-200 w-20 text-right" tooltip={step.visitors.toLocaleString()}>
            {numberShortFormatter(step.visitors)}
          </span>
        </div>
      </>
    )
  }

  const renderBars = (funnel) => {
    return (
      <>
        <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
          <span>&nbsp;</span>
          <span className="text-right">
            <span className="inline-block w-20">Visitors</span>
          </span>
        </div>
        <FlipMove>
          {funnel.steps.map(renderBar)}
        </FlipMove>
      </>
    )
  }

  return (
    <div style={{ minHeight: '400px' }}>
      <LazyLoader onVisible={() => setVisible(true)}>
        {renderInner()}
      </LazyLoader>
      {!isSmallScreen && <canvas className="" id="funnel" ref={canvasRef}></canvas>}
    </div>
  )
}
