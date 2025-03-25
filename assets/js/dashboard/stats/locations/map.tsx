import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import * as d3 from 'd3'
import classNames from 'classnames'
import * as api from '../../api'
import { replaceFilterByPrefix, cleanLabels } from '../../util/filters'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { numberShortFormatter } from '../../util/number-formatter'
import * as topojson from 'topojson-client'
import { useQuery } from '@tanstack/react-query'
import { useSiteContext } from '../../site-context'
import { useQueryContext } from '../../query-context'
import worldJson from 'visionscarto-world-atlas/world/110m.json'
import { UIMode, useTheme } from '../../theme-context'
import { apiPath } from '../../util/url'
import MoreLink from '../more-link'
import { countriesRoute } from '../../router'
import { MIN_HEIGHT } from '../reports/list'
import { MapTooltip } from './map-tooltip'
import { GeolocationNotice } from './geolocation-notice'

const width = 475
const height = 335

type CountryData = {
  alpha_3: string
  name: string
  visitors: number
  code: string
}
type WorldJsonCountryData = { properties: { name: string; a3: string } }

const WorldMap = ({
  onCountrySelect,
  afterFetchData
}: {
  onCountrySelect: () => void
  afterFetchData: (response: unknown) => void
}) => {
  const navigate = useAppNavigate()
  const { mode } = useTheme()
  const site = useSiteContext()
  const { query } = useQueryContext()
  const svgRef = useRef<SVGSVGElement | null>(null)
  const [tooltip, setTooltip] = useState<{
    x: number
    y: number
    hoveredCountryAlpha3Code: string | null
  }>({ x: 0, y: 0, hoveredCountryAlpha3Code: null })

  const labels =
    query.period === 'realtime'
      ? { singular: 'Current visitor', plural: 'Current visitors' }
      : { singular: 'Visitor', plural: 'Visitors' }

  const { data, refetch, isFetching, isError } = useQuery({
    queryKey: ['countries', 'map', query],
    placeholderData: (previousData) => previousData,
    queryFn: async (): Promise<{
      results: CountryData[]
    }> => {
      return await api.get(apiPath(site, '/countries'), query, {
        limit: 300
      })
    }
  })

  useEffect(() => {
    const onTickRefetchData = () => {
      if (query.period === 'realtime') {
        refetch()
      }
    }
    document.addEventListener('tick', onTickRefetchData)
    return () => document.removeEventListener('tick', onTickRefetchData)
  }, [query.period, refetch])

  useEffect(() => {
    if (data) {
      afterFetchData(data)
    }
  }, [afterFetchData, data])

  const { maxValue, dataByCountryCode } = useMemo(() => {
    const dataByCountryCode: Map<string, CountryData> = new Map()
    let maxValue = 0
    for (const { alpha_3, visitors, name, code } of data?.results || []) {
      if (visitors > maxValue) {
        maxValue = visitors
      }
      dataByCountryCode.set(alpha_3, { alpha_3, visitors, name, code })
    }
    return { maxValue, dataByCountryCode }
  }, [data])

  const onCountryClick = useCallback(
    (d: WorldJsonCountryData) => {
      const country = dataByCountryCode.get(d.properties.a3)
      const clickable = country && country.visitors
      if (clickable) {
        const filters = replaceFilterByPrefix(query, 'country', [
          'is',
          'country',
          [country.code]
        ])
        const labels = cleanLabels(filters, query.labels, 'country', {
          [country.code]: country.name
        })
        onCountrySelect()
        navigate({ search: (search) => ({ ...search, filters, labels }) })
      }
    },
    [navigate, query, dataByCountryCode, onCountrySelect]
  )

  useEffect(() => {
    if (!svgRef.current) {
      return
    }

    const svg = drawInteractiveCountries(svgRef.current, setTooltip)

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
        dataByCountryCode
      ).on('click', (_event, countryPath) => {
        onCountryClick(countryPath as unknown as WorldJsonCountryData)
      })
    }
  }, [mode, maxValue, dataByCountryCode, onCountryClick])

  const hoveredCountryData = tooltip.hoveredCountryAlpha3Code
    ? dataByCountryCode.get(tooltip.hoveredCountryAlpha3Code)
    : undefined

  return (
    <div className="flex flex-col relative" style={{ minHeight: MIN_HEIGHT }}>
      <div className="mt-4" />
      <div
        className="relative mx-auto w-full"
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
              labels[hoveredCountryData.visitors === 1 ? 'singular' : 'plural']
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
      <MoreLink
        list={data?.results ?? []}
        linkProps={{
          path: countriesRoute.path,
          search: (search: Record<string, unknown>) => search
        }}
        className={undefined}
        onClick={undefined}
      />
      {site.isDbip && <GeolocationNotice />}
    </div>
  )
}

const colorScales = {
  [UIMode.dark]: ['#2e3954', '#6366f1'],
  [UIMode.light]: ['#f3ebff', '#a779e9']
}

const sharedCountryClass = classNames('transition-colors')

const countryClass = classNames(
  sharedCountryClass,
  'stroke-1',
  'fill-[#f8fafc]',
  'stroke-[#dae1e7]',
  'dark:fill-[#2d3747]',
  'dark:stroke-[#1f2937]'
)

const highlightedCountryClass = classNames(
  sharedCountryClass,
  'stroke-2',
  'fill-[#f5f5f5]',
  'stroke-[#a779e9]',
  'dark:fill-[#374151]',
  'dark:stroke-[#4f46e5]'
)

/**
 * Used to color the countries
 * @returns the svg elements represeting countries
 */
function colorInCountriesWithValues(
  element: SVGSVGElement,
  getColorForValue: d3.ScaleLinear<string, string, never>,
  dataByCountryCode: Map<string, CountryData>
) {
  function getCountryByCountryPath(countryPath: unknown) {
    return dataByCountryCode.get(
      (countryPath as unknown as WorldJsonCountryData).properties.a3
    )
  }

  const svg = d3.select(element)

  return svg
    .selectAll('path')
    .style('fill', (countryPath) => {
      const country = getCountryByCountryPath(countryPath)
      if (!country?.visitors) {
        return null
      }
      return getColorForValue(country.visitors)
    })
    .style('cursor', (countryPath) => {
      const country = getCountryByCountryPath(countryPath)
      if (!country?.visitors) {
        return null
      }
      return 'pointer'
    })
}

/** @returns the d3 selected svg element */
function drawInteractiveCountries(
  element: SVGSVGElement,
  setTooltip: React.Dispatch<
    React.SetStateAction<{
      x: number
      y: number
      hoveredCountryAlpha3Code: string | null
    }>
  >
) {
  const path = setupProjetionPath()
  const data = parseWorldTopoJsonToGeoJsonFeatures()
  const svg = d3.select(element)

  svg
    .selectAll('path')
    .data(data)
    .enter()
    .append('path')
    .attr('class', countryClass)
    .attr('d', path as never)

    .on('mouseover', function (event, country) {
      const [x, y] = d3.pointer(event, svg.node()?.parentNode)
      setTooltip({ x, y, hoveredCountryAlpha3Code: country.properties.a3 })
      // brings country to front
      this.parentNode?.appendChild(this)
      d3.select(this).attr('class', highlightedCountryClass)
    })

    .on('mousemove', function (event) {
      const [x, y] = d3.pointer(event, svg.node()?.parentNode)
      setTooltip((currentState) => ({ ...currentState, x, y }))
    })

    .on('mouseout', function () {
      setTooltip({ x: 0, y: 0, hoveredCountryAlpha3Code: null })
      d3.select(this).attr('class', countryClass)
    })

  return svg
}

function setupProjetionPath() {
  const projection = d3
    .geoMercator()
    .scale(75)
    .translate([width / 2, height / 1.5])

  const path = d3.geoPath().projection(projection)
  return path
}

function parseWorldTopoJsonToGeoJsonFeatures(): Array<WorldJsonCountryData> {
  const collection = topojson.feature(
    // @ts-expect-error strings in worldJson not recongizable as the enum values declared in library
    worldJson,
    worldJson.objects.countries
  )
  // @ts-expect-error topojson.feature return type incorrectly inferred as not a collection
  return collection.features
}

export default WorldMap
