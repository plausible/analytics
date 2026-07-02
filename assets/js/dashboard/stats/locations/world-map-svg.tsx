import React, { useEffect, useRef, useState } from 'react'
import * as d3 from 'd3'
import classNames from 'classnames'
import { numberShortFormatter } from '../../util/number-formatter'
import { UIMode } from '../../theme-context'
import { MapTooltip } from './map-tooltip'
import {
  parseWorldTopoJsonToGeoJsonFeatures,
  WorldJsonCountryData
} from './countries'

export const MAP_CONTAINER_WIDTH = 475
export const MAP_CONTAINER_HEIGHT = 335

export type CountryData = {
  alpha_3: string
  name: string
  visitors: number
  code: string
}

export type MetricLabel = { singular: string; plural: string }

export function WorldMapSvg({
  maxValue,
  dataByAlpha3Code,
  metricLabel,
  mode,
  onCountryClick
}: {
  maxValue: number
  dataByAlpha3Code: Map<string, CountryData>
  metricLabel: MetricLabel
  mode: UIMode
  onCountryClick: (country: CountryData) => void
}) {
  const svgRef = useRef<SVGSVGElement | null>(null)
  const [tooltip, setTooltip] = useState<{
    x: number
    y: number
    hoveredCountryAlpha3Code: string | null
  }>({ x: 0, y: 0, hoveredCountryAlpha3Code: null })

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
    if (!svgRef.current) {
      return
    }

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
      const country = dataByAlpha3Code.get(
        (countryPath as unknown as WorldJsonCountryData).properties.a3
      )
      if (country?.visitors) {
        onCountryClick(country)
      }
    })
  }, [mode, maxValue, dataByAlpha3Code, onCountryClick])

  const hoveredCountryData = tooltip.hoveredCountryAlpha3Code
    ? dataByAlpha3Code.get(tooltip.hoveredCountryAlpha3Code)
    : undefined

  return (
    <>
      <svg
        ref={svgRef}
        viewBox={`0 0 ${MAP_CONTAINER_WIDTH} ${MAP_CONTAINER_HEIGHT}`}
        className="w-full opacity-100 transition-opacity duration-300 starting:opacity-0"
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
    </>
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
  const path = setupProjectionPath()
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

function setupProjectionPath() {
  const projection = d3
    .geoMercator()
    .scale(75)
    .translate([MAP_CONTAINER_WIDTH / 2, MAP_CONTAINER_HEIGHT / 1.5])

  const path = d3.geoPath().projection(projection)
  return path
}
