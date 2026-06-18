import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import * as d3 from 'd3'
import classNames from 'classnames'
import {
  replaceFilterByPrefix,
  cleanLabels,
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { numberShortFormatter } from '../../util/number-formatter'
import { useSiteContext } from '../../site-context'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { UIMode, useTheme } from '../../theme-context'
import { MIN_HEIGHT } from '../reports/index-breakdown'
import { MapTooltip } from './map-tooltip'
import { GeolocationNotice } from './geolocation-notice'
import { DashboardState } from '../../dashboard-state'
import { useQueryApi } from '../../hooks/use-query-api'
import { QueryApiResponse } from '../../api'
import {
  COUNTRIES_BY_TWO_LETTER_CODE,
  parseWorldTopoJsonToGeoJsonFeatures,
  WorldJsonCountryData
} from './countries'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'

const width = 475
const height = 335

type CountryData = {
  alpha_3: string
  name: string
  visitors: number
  code: string
}

function getMetricLabel(dashboardState: DashboardState) {
  if (hasConversionGoalFilter(dashboardState)) {
    return { singular: 'Conversion', plural: 'Conversions' }
  }
  if (isRealTimeDashboard(dashboardState)) {
    return { singular: 'Current visitor', plural: 'Current visitors' }
  }
  return { singular: 'Visitor', plural: 'Visitors' }
}

const WorldMap = ({
  onCountrySelect,
  onDataReady
}: {
  onCountrySelect: () => void
  onDataReady: (response: QueryApiResponse) => void
}) => {
  const navigate = useAppNavigate()
  const { mode } = useTheme()
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const svgRef = useRef<SVGSVGElement | null>(null)
  const [tooltip, setTooltip] = useState<{
    x: number
    y: number
    hoveredCountryAlpha3Code: string | null
  }>({ x: 0, y: 0, hoveredCountryAlpha3Code: null })

  const metricLabel = useMemo(
    () => getMetricLabel(dashboardState),
    [dashboardState]
  )

  const { apiState } = useQueryApi(site, [
    'visit:country',
    {
      dashboardState,
      reportParams: {
        metrics: ['visitors'],
        dimensions: BREAKDOWN_REPORTS[BreakdownReportKey.countries].dimensions,
        alwaysOnFilters:
          BREAKDOWN_REPORTS[BreakdownReportKey.countries].alwaysOnFilters,
        order_by: [['visitors', 'desc']],
        pagination: { limit: 300, offset: 0 }
      }
    }
  ])
  const { data, isFetching, isError } = apiState

  useEffect(() => {
    if (data) {
      onDataReady(data)
    }
  }, [onDataReady, data])

  const { maxValue, dataByAlpha3Code } = useMemo(() => {
    const dataByAlpha3Code: Map<string, CountryData> = new Map()
    let maxValue = 0
    for (const row of data?.results ?? []) {
      const [countryName, countryCode] = row.dimensions
      const [visitors] = row.metrics as [number]
      const entry = COUNTRIES_BY_TWO_LETTER_CODE[countryCode]
      if (!entry || !entry.alpha_3) continue
      if (visitors > maxValue) {
        maxValue = visitors
      }
      dataByAlpha3Code.set(entry.alpha_3, {
        alpha_3: entry.alpha_3,
        visitors,
        name: countryName,
        code: countryCode
      })
    }
    return { maxValue, dataByAlpha3Code }
  }, [data])

  const onCountryClick = useCallback(
    (d: WorldJsonCountryData) => {
      const country = dataByAlpha3Code.get(d.properties.a3)
      const clickable = country && country.visitors
      if (clickable) {
        const filters = replaceFilterByPrefix(dashboardState, 'country', [
          'is',
          'country',
          [country.code]
        ])
        const labels = cleanLabels(filters, dashboardState.labels, 'country', {
          [country.code]: country.name
        })
        onCountrySelect()
        navigate({
          search: (searchRecord) => ({ ...searchRecord, filters, labels })
        })
      }
    },
    [navigate, dashboardState, dataByAlpha3Code, onCountrySelect]
  )

  useEffect(() => {
    if (!svgRef.current) {
      return
    }

    const { svg, countriesSelection } = drawInteractiveCountries(svgRef.current)
    const highlightSelection = drawHighlightedCountryOutline(svgRef.current)

    countriesSelection
      .on('mouseover', function (event, country) {
        const [x, y] = d3.pointer(event, svg.node()?.parentNode)
        setTooltip({ x, y, hoveredCountryAlpha3Code: country.properties.a3 })

        highlightSelection
          .attr('d', this.getAttribute('d'))
          .attr('class', hoveredOutlineClass)
      })

      .on('mousemove', function (event) {
        const [x, y] = d3.pointer(event, svg.node()?.parentNode)
        setTooltip((currentState) => ({ ...currentState, x, y }))
      })

      .on('mouseout', function () {
        setTooltip({ x: 0, y: 0, hoveredCountryAlpha3Code: null })
        highlightSelection.attr('d', null).attr('class', initialOutlineClass)
      })

    return () => {
      svg.selectAll('*').remove()
    }
  }, [])

  useEffect(() => {
    if (svgRef.current) {
      const palette = colorScales[mode]

      const getColorForValue = d3
        .scaleLinear<string>()
        .domain([0, maxValue])
        .range(palette)

      colorInCountriesWithValues(
        svgRef.current,
        getColorForValue,
        dataByAlpha3Code
      ).on('click', (_event, countryPath) => {
        onCountryClick(countryPath as unknown as WorldJsonCountryData)
      })
    }
  }, [mode, maxValue, dataByAlpha3Code, onCountryClick])

  const hoveredCountryData = tooltip.hoveredCountryAlpha3Code
    ? dataByAlpha3Code.get(tooltip.hoveredCountryAlpha3Code)
    : undefined

  return (
    <div
      className="flex flex-col justify-center items-center relative"
      style={{ minHeight: MIN_HEIGHT }}
    >
      <div
        className="relative flex justify-center items-center mt-4 w-full"
        style={{ height: height, maxWidth: width }}
      >
        <svg
          ref={svgRef}
          viewBox={`0 0 ${width} ${height}`}
          className="w-full"
        />
        {!!hoveredCountryData && (
          <MapTooltip
            x={tooltip.x}
            y={tooltip.y}
            name={hoveredCountryData.name}
            value={numberShortFormatter(hoveredCountryData.visitors)}
            label={
              hoveredCountryData.visitors === 1
                ? metricLabel.singular
                : metricLabel.plural
            }
          />
        )}
        {isFetching ||
          (isError && (
            <div className="absolute inset-0 flex justify-center items-center">
              <div className="loading">
                <div />
              </div>
            </div>
          ))}
      </div>
      {site.isDbip && <GeolocationNotice />}
    </div>
  )
}

const colorScales = {
  [UIMode.dark]: ['#2a276d', '#6366f1'], // custom color between indigo-900 and indigo-950, indigo-500
  [UIMode.light]: ['#e0e7ff', '#818cf8'] // indigo-100, indigo-400
}

const countryElementClass = 'country'
const countrySelector = `path.${countryElementClass}`
const initialStroke = classNames(
  'stroke-white',
  'dark:stroke-gray-900',
  'stroke-1px'
)
const hoveredStroke = classNames(
  'stroke-[1.5px]',
  'stroke-indigo-400',
  'dark:stroke-indigo-500'
)

const countryClass = classNames(
  countryElementClass,
  initialStroke,
  'transition-colors',
  'stroke-1',
  'fill-gray-150',
  'dark:fill-gray-750'
)

const sharedOutlineClass = classNames(
  'transition-colors',
  'fill-none',
  'pointer-events-none'
)

const initialOutlineClass = classNames(
  sharedOutlineClass,
  initialStroke,
  'opacity-0'
)
const hoveredOutlineClass = classNames(sharedOutlineClass, hoveredStroke)

/**
 * Used to color the countries
 * @returns the svg elements represeting countries
 */
function colorInCountriesWithValues(
  element: SVGSVGElement,
  getColorForValue: d3.ScaleLinear<string, string, never>,
  dataByCountryCode: Map<string, CountryData>
) {
  const svg = d3.select(element)

  return svg
    .selectAll<SVGPathElement, WorldJsonCountryData>(countrySelector)
    .style('fill', (countryPath) => {
      const country = dataByCountryCode.get(countryPath.properties.a3)
      if (!country?.visitors) {
        return null
      }
      return getColorForValue(country.visitors)
    })
    .style('cursor', (countryPath) => {
      const country = dataByCountryCode.get(countryPath.properties.a3)
      if (!country?.visitors) {
        return null
      }
      return 'pointer'
    })
}

function drawHighlightedCountryOutline(element: SVGSVGElement) {
  return d3.select(element).append('path').attr('class', initialOutlineClass)
}

function drawInteractiveCountries(element: SVGSVGElement) {
  const path = setupProjetionPath()
  const data = parseWorldTopoJsonToGeoJsonFeatures()
  const svg = d3.select(element)

  const countriesSelection = svg
    .selectAll(countrySelector)
    .data(data)
    .enter()
    .append('path')
    .attr('class', countryClass)
    .attr('d', path as never)

  return { svg, countriesSelection }
}

function setupProjetionPath() {
  const projection = d3
    .geoMercator()
    .scale(75)
    .translate([width / 2, height / 1.5])

  const path = d3.geoPath().projection(projection)
  return path
}

export default WorldMap
