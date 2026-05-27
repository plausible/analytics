import React, { useEffect, useMemo } from 'react'
import { numberShortFormatter } from '../../util/number-formatter'
import RocketIcon from '../modals/rocket-icon'
import LazyLoader from '../../components/lazy-loader'
import { PlausibleSite, useSiteContext } from '../../site-context'
import {
  SearchTermsErrorCode,
  SearchTermsErrorPayload,
  SearchTermsResultItem,
  SearchTermsSuccessResponse,
  useIndexGoogleSearchTermsQuery
} from './fetch-search-terms'
import {
  Bar,
  DEFAULT_METRIC_COLUMN_WIDTH,
  IndexBreakdownRenderer
} from '../reports/index-breakdown'
import { ColumnConfiguration } from '../breakdowns'

function ErrorMessage({ code }: { code: SearchTermsErrorCode }): JSX.Element {
  if (code === 'not_configured') {
    return <div>The site is not connected to Google Search Keywords</div>
  } else if (code === 'unsupported_filters') {
    return (
      <div>
        Unable to fetch keyword data from Search Console because it does not
        support the current set of filters
      </div>
    )
  } else if (code === 'period_too_recent') {
    return (
      <div>
        No search terms were found for this period. Please adjust or extend your
        time range. Check{' '}
        <a
          href="https://plausible.io/docs/google-search-console-integration#i-dont-see-google-search-query-data-in-my-dashboard"
          target="_blank"
          rel="noreferrer"
          className="hover:underline text-indigo-700 dark:text-indigo-500"
        >
          our documentation
        </a>{' '}
        for more details.
      </div>
    )
  } else {
    return <div>Unable to fetch keyword data from Search Console</div>
  }
}

function ConfigureSearchTermsCTA({
  site
}: {
  site: PlausibleSite
}): JSX.Element {
  return (
    <>
      <div>Configure the integration to view search terms</div>
      <a
        href={`/${encodeURIComponent(site.domain)}/settings/integrations`}
        className="button mt-4"
      >
        Connect with Google
      </a>
    </>
  )
}

export function SearchTerms({
  onDataReady
}: {
  onDataReady: (data: SearchTermsSuccessResponse) => void
}) {
  const site = useSiteContext()

  const [visible, setVisible] = React.useState(false)

  const apiState = useIndexGoogleSearchTermsQuery({ enabled: visible })

  useEffect(() => {
    if (apiState.data) {
      onDataReady(apiState.data)
    }
  }, [apiState.data, onDataReady])

  const barMaxValue = useMemo(() => {
    if (apiState.data?.results?.length) {
      return Math.max(...apiState.data.results.map((item) => item.visitors))
    } else {
      return null
    }
  }, [apiState.data])

  const columns = useMemo(():
    | ColumnConfiguration<SearchTermsResultItem>[]
    | null => {
    if (!barMaxValue) {
      return null
    }

    return [
      {
        key: 'dimension',
        renderLabel: () => 'Search term',
        renderCell: (item, _isActive) => (
          <div className="relative h-full w-full">
            <Bar
              barWidthPercent={(item.visitors / barMaxValue) * 100}
              className="bg-blue-50 group-hover/row:bg-blue-100"
            />
            <span className="flex px-2 py-1.5 text-sm dark:text-gray-300 relative z-9 break-all">
              {item.name}
            </span>
          </div>
        ),
        align: 'left'
      },
      {
        key: 'visitors',
        renderLabel: () => 'Visitors',
        renderCell: (item, _isActive) => (
          <span
            className="font-medium font-medium text-sm block text-gray-800 dark:text-gray-200"
            data-testid="metric-value"
          >
            {numberShortFormatter(item.visitors)}
          </span>
        ),
        width: DEFAULT_METRIC_COLUMN_WIDTH,
        align: 'right'
      }
    ]
  }, [barMaxValue])

  if (apiState.error) {
    const { is_admin, error_code } = apiState.error
      .payload as SearchTermsErrorPayload

    return (
      <div className="text-center text-gray-700 dark:text-gray-300 text-sm mt-20">
        <RocketIcon />
        <ErrorMessage code={error_code} />
        {error_code === 'not_configured' && is_admin && (
          <ConfigureSearchTermsCTA site={site} />
        )}
      </div>
    )
  }
  return (
    <LazyLoader onVisible={() => setVisible(true)}>
      <IndexBreakdownRenderer<SearchTermsResultItem>
        {...apiState}
        rows={apiState.data?.results ?? []}
        getDimensionValue={(row) => row.name}
        isRealtimeSilentUpdate={false}
        columns={columns}
      />
    </LazyLoader>
  )
}
