import React, { ReactNode } from 'react'
import { revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'
import {
  DetailsBreakdown,
  DimensionCell,
  DimensionCellProps
} from '../modals/details-breakdown'
import Modal from '../modals/modal'
import {
  getCitiesFilterInfo,
  getCountriesFilterInfo,
  getRegionsFilterInfo,
  LocationsReportKey
} from '.'
import { FlagEmoji } from './flag-emoji'

export function LocationsDetails({
  reportKey
}: {
  reportKey: LocationsReportKey
}) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  const reportConfig = BREAKDOWN_REPORTS[reportKey]

  /*global BUILD_EXTRA*/
  const isRevenueAvailable =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  const metrics = reportConfig.getMetrics({
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
    isRealtime: isRealTimeDashboard(dashboardState),
    isDetailed: true,
    isRevenueAvailable: isRevenueAvailable
  })

  const DimensionElement = DIMENSION_ELEMENTS[reportKey]

  return (
    <Modal>
      <DetailsBreakdown
        title={reportConfig.detailsTitle}
        dimensionLabel={reportConfig.dimensionLabel}
        dimensions={reportConfig.dimensions}
        metrics={metrics}
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        defaultOrderBy={[['visitors', 'desc']]}
        DimensionElement={DimensionElement}
      />
    </Modal>
  )
}

const CountryDimensionCell = (props: DimensionCellProps) => {
  const [countryName, countryCode] = props.row.dimensions
  return (
    <DimensionCell
      {...props}
      text={countryName}
      icon={<FlagEmoji countryCode={countryCode} />}
      getFilterInfo={getCountriesFilterInfo}
    />
  )
}

const RegionsDimensionCell = (props: DimensionCellProps) => {
  const [regionName, _regionCode, countryCode] = props.row.dimensions
  return (
    <DimensionCell
      {...props}
      text={regionName}
      icon={<FlagEmoji countryCode={countryCode} />}
      getFilterInfo={getRegionsFilterInfo}
    />
  )
}

const CitiesDimensionCell = (props: DimensionCellProps) => {
  const [cityName, _cityCode, countryCode] = props.row.dimensions
  return (
    <DimensionCell
      {...props}
      text={cityName}
      icon={<FlagEmoji countryCode={countryCode} />}
      getFilterInfo={getCitiesFilterInfo}
    />
  )
}

const DIMENSION_ELEMENTS: Record<
  LocationsReportKey,
  (props: DimensionCellProps) => ReactNode
> = {
  [BreakdownReportKey.countries]: CountryDimensionCell,
  [BreakdownReportKey.regions]: RegionsDimensionCell,
  [BreakdownReportKey.cities]: CitiesDimensionCell
}
