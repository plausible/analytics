import React, { ReactNode } from 'react'
import {
  AppNavigationLink,
  AppNavigationLinkProps
} from '../navigation/use-app-navigate'
import classNames from 'classnames'
import { cleanLabels, replaceFilterByPrefix } from '../util/filters'
import { plainFilterText } from '../util/filter-text'
import { useDashboardStateContext } from '../dashboard-state-context'
import { Filter, FilterClauseLabels } from '../dashboard-state'

export type FilterInfo = {
  prefix: string
  filter: Filter
  labels?: FilterClauseLabels
  extraFilters?: Array<{ prefix: string; filter: Filter }>
}

export function DrilldownLink({
  path,
  filterInfo,
  onClick,
  children,
  icon,
  className,
  textClassName
}: Pick<AppNavigationLinkProps, 'path' | 'onClick' | 'children'> & {
  className?: string
  textClassName?: string
  icon?: ReactNode
  filterInfo: FilterInfo | null
}) {
  const { dashboardState } = useDashboardStateContext()

  if (filterInfo) {
    const { prefix, filter, labels, extraFilters = [] } = filterInfo
    let newFilters = replaceFilterByPrefix(dashboardState, prefix, filter)
    let newLabels = cleanLabels(
      newFilters,
      dashboardState.labels,
      filter[1],
      labels
    )

    for (const ef of extraFilters) {
      newFilters = replaceFilterByPrefix(
        { ...dashboardState, filters: newFilters },
        ef.prefix,
        ef.filter
      )
      newLabels = cleanLabels(newFilters, newLabels, ef.filter[1], undefined)
    }

    const allFilters = [filter, ...extraFilters.map((ef) => ef.filter)]
    const title = allFilters
      .map((f) => plainFilterText({ ...dashboardState, labels: newLabels }, f))
      .join(' and ')

    return (
      <AppNavigationLink
        title={`Add filter: ${title}`}
        className={classNames(className, 'group')}
        path={path}
        onClick={onClick}
        search={(search) => ({
          ...search,
          filters: newFilters,
          labels: newLabels
        })}
      >
        {icon}
        <span className={classNames(textClassName, 'group-hover:underline')}>
          {children}
        </span>
      </AppNavigationLink>
    )
  } else {
    return (
      <span className={className}>
        {icon}
        <span className={textClassName}>{children}</span>
      </span>
    )
  }
}
