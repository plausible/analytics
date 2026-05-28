import React, { ReactNode } from 'react'
import { useDashboardStateContext } from '../../dashboard-state-context'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { chooseBreakdownMetricsByContext } from '../breakdowns'
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
  const reportConfig = BREAKDOWN_REPORTS[reportKey]

  const metrics = chooseBreakdownMetricsByContext(
    reportConfig.metricsByContext,
    {
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
      isRealtime: isRealTimeDashboard(dashboardState),
      isDetailed: true,
      isRevenueAvailable: false
    }
  )

  const DimensionElement = DIMENSION_ELEMENTS[reportKey]

  return (
    <Modal>
      <DetailsBreakdown
        title={reportConfig.detailsTitle}
        dimensionLabel={reportConfig.dimensionLabel}
        dimensions={reportConfig.dimensions}
        metrics={metrics}
        defaultOrderBy={[['visitors', 'desc']]}
        searchEnabled={false}
        DimensionElement={DimensionElement}
      />
    </Modal>
  )
}

const CountryDimensionCell = (props: DimensionCellProps) => {
  const [countryCode, countryName] = props.row.dimensions
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
  const [_regionCode, regionName, countryCode] = props.row.dimensions
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
  const [_cityCode, cityName, countryCode] = props.row.dimensions
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
