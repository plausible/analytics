import React from 'react'
import { SearchTerms } from './search-terms'
import SourceList from './source-list'
import ReferrerList from './referrer-list'
import {
  getFiltersByKeyPrefix,
  isFilteringOnFixedValue
} from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'

export default function Sources() {
  const { dashboardState } = useDashboardStateContext()

  if (isFilteringOnFixedValue(dashboardState, 'source', 'Google')) {
    return <SearchTerms />
  } else if (isFilteringOnFixedValue(dashboardState, 'source')) {
    const [[_operation, _filterKey, clauses]] = getFiltersByKeyPrefix(
      dashboardState,
      'source'
    )
    return <ReferrerList source={clauses[0]} />
  } else {
    return <SourceList />
  }
}
