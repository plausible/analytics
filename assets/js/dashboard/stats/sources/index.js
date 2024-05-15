import React from 'react';
import SearchTerms from './search-terms'
import SourceList from './source-list'
import ReferrerList from './referrer-list'
import { isFilteringOnFixedValue } from '../../util/filters'


export default function Sources(props) {
  const { site, query } = props

  const filtersBySource = isFilteringOnFixedValue(query, 'source')
  const includesImported = query.with_imported && site.hasImportedData

  if (props.query.filters.source === 'Google') {
    return <SearchTerms {...props} />
  } else if (filtersBySource && !includesImported) {
    return <ReferrerList {...props} />
  } else  {
    return <SourceList {...props} />
  }
}
