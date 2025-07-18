import React, { useEffect, useCallback } from 'react'
import FadeIn from '../../fade-in'
import Bar from '../bar'
import MoreLink from '../more-link'
import { numberShortFormatter } from '../../util/number-formatter'
import RocketIcon from '../modals/rocket-icon'
import * as api from '../../api'
import LazyLoader from '../../components/lazy-loader'
import { referrersGoogleRoute } from '../../router'
import { useQueryContext } from '../../query-context'
import { PlausibleSite, useSiteContext } from '../../site-context'

interface SearchTerm {
  name: string
  visitors: number
}

type ErrorCode = 'not_configured' | 'unsupported_filters' | 'period_too_recent'

interface ErrorPayload {
  error_code: ErrorCode
  is_admin: boolean
}

function ErrorMessage({ code }: { code: ErrorCode }): JSX.Element {
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

export function SearchTerms() {
  const site = useSiteContext()
  const { query } = useQueryContext()

  const [loading, setLoading] = React.useState(true)
  const [errorPayload, setErrorPayload] = React.useState<null | ErrorPayload>(
    null
  )
  const [searchTerms, setSearchTerms] = React.useState<null | SearchTerm[]>(
    null
  )
  const [visible, setVisible] = React.useState(false)

  const fetchSearchTerms = useCallback(() => {
    api
      .get(
        `/api/stats/${encodeURIComponent(site.domain)}/referrers/Google`,
        query
      )
      .then((res) => {
        setLoading(false)
        setSearchTerms(res.results)
        setErrorPayload(null)
      })
      .catch((error) => {
        setLoading(false)
        setSearchTerms(null)
        setErrorPayload(error.payload)
      })
  }, [query, site.domain])

  useEffect(() => {
    if (visible) {
      setLoading(true)
      setSearchTerms([])
      fetchSearchTerms()
    }
  }, [query, fetchSearchTerms, visible])

  const onVisible = () => {
    setVisible(true)
  }

  const renderList = () => {
    if (searchTerms && searchTerms.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 dark:text-gray-400 text-xs font-bold tracking-wide">
            <span>Search term</span>
            <span>Visitors</span>
          </div>
          {searchTerms &&
            searchTerms.map((term: SearchTerm) => (
              <div
                className="flex items-center justify-between my-1 text-sm"
                key={term.name}
              >
                <Bar
                  count={term.visitors}
                  all={searchTerms}
                  bg="bg-blue-50 dark:bg-gray-500 dark:bg-opacity-15"
                  maxWidthDeduction="4rem"
                >
                  <span className="flex px-2 py-1.5 dark:text-gray-300 z-9 relative break-all">
                    <span className="md:truncate block">{term.name}</span>
                  </span>
                </Bar>
                <span className="font-medium dark:text-gray-200">
                  {numberShortFormatter(term.visitors)}
                </span>
              </div>
            ))}
          <MoreLink
            list={searchTerms}
            linkProps={{
              path: referrersGoogleRoute.path,
              search: (search: Record<string, unknown>) => search
            }}
            className="w-full mt-2"
            onClick={undefined}
          />
        </React.Fragment>
      )
    }
  }

  const renderNoDataYet = () => {
    if (searchTerms && searchTerms.length === 0) {
      return (
        <div className="text-center text-gray-700 dark:text-gray-300 ">
          <div className="mt-44 mx-auto font-medium text-gray-500 dark:text-gray-400">
            No data yet
          </div>
        </div>
      )
    }
  }

  const renderError = () => {
    if (errorPayload) {
      const { is_admin, error_code } = errorPayload

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
  }

  return (
    <div className="flex flex-col h-full">
      <h3 className="font-bold dark:text-gray-100">Suchbegriffe</h3>
      <div className="relative flex-grow">
        {loading && (
          <div className="absolute inset-0 flex justify-center items-center">
            <div className="loading">
              <div />
            </div>
          </div>
        )}
        <FadeIn show={!loading} className="flex-grow">
          <LazyLoader onVisible={onVisible}>
            {searchTerms && searchTerms.length > 0 && renderList()}
            {searchTerms && searchTerms.length === 0 && renderNoDataYet()}
            {errorPayload && renderError()}
          </LazyLoader>
        </FadeIn>
      </div>
    </div>
  )
}
