import React from 'react';
import SearchTerms from './search-terms';
import SourceList from './source-list';
import ReferrerList from './referrer-list';
import { getFiltersByKeyPrefix, isFilteringOnFixedValue } from '../../util/filters';
import { useQueryContext } from '../../query-context';
import { useSiteContext } from '../../site-context';

export default function Sources() {
  const { query } = useQueryContext();
  const site = useSiteContext();
  if (isFilteringOnFixedValue(query, 'source', 'Google')) {
    return <SearchTerms query={query} site={site} />
  } else if (isFilteringOnFixedValue(query, 'source')) {
    const [[_operation, _filterKey, clauses]] = getFiltersByKeyPrefix(query, "source")
    return <ReferrerList source={clauses[0]} />
  } else {
    return <SourceList />
  }
}
