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
import { useSiteContext } from '../../site-context'

function ErrorMessage({ code }) {
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
        time range. Check
        <a
          href="https://plausible.io/docs/google-search-console-integration#i-dont-see-google-search-query-data-in-my-dashboard"
          target="_blank"
          rel="noreferrer"
          className="hover:underline text-indigo-700 dark:text-indigo-500"
        >
          our documentation
        </a>
        for more details.
      </div>
    )
  }
}

function ConfigureSearchTermsCTA({ site }) {
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
  const [errorPayload, setErrorPayload] = React.useState(null)
  const [searchTerms, setSearchTerms] = React.useState(null)
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
        setSearchTerms([])
        setErrorPayload(error.payload)
      })
  }, [query, site.domain])

  useEffect(() => {
    if (visible) {
      setLoading(true)
      setSearchTerms(null)
      fetchSearchTerms()
    }
  }, [query, fetchSearchTerms, visible])

  const onVisible = () => {
    setVisible(true)
  }

  const renderSearchTerm = (term) => {
    return (
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
    )
  }

  const renderList = () => {
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
    } else if (searchTerms.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 dark:text-gray-400 text-xs font-bold tracking-wide">
            <span>Search term</span>
            <span>Visitors</span>
          </div>
          {searchTerms.map(renderSearchTerm)}
        </React.Fragment>
      )
    } else {
      return (
        <div className="text-center text-gray-700 dark:text-gray-300 ">
          <div className="mt-44 mx-auto font-medium text-gray-500 dark:text-gray-400">
            No data yet
          </div>
        </div>
      )
    }
  }

  const renderContent = () => {
    if (searchTerms) {
      return (
        <React.Fragment>
          <h3 className="font-bold dark:text-gray-100">Search Terms</h3>
          {renderList()}
          <MoreLink
            list={searchTerms}
            linkProps={{
              path: referrersGoogleRoute.path,
              search: (search) => search
            }}
            className="w-full pb-4 absolute bottom-0 left-0"
          />
        </React.Fragment>
      )
    }
  }

  return (
    <div>
      {loading && <div className="loading mt-44 mx-auto"><div></div></div>}
      <FadeIn show={!loading} className="flex-grow">
        <LazyLoader onVisible={onVisible}>
          {renderContent()}
        </LazyLoader>
      </FadeIn>
    </div>
  )
}
