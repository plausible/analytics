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
    const { prefix, filter, labels } = filterInfo
    const newFilters = replaceFilterByPrefix(dashboardState, prefix, filter)
    const newLabels = cleanLabels(
      newFilters,
      dashboardState.labels,
      filter[1],
      labels
    )

    return (
      <AppNavigationLink
        title={`Add filter: ${plainFilterText({ ...dashboardState, labels: newLabels }, filter)}`}
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
