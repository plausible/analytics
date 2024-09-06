/** @format */

import React, { useState, ReactNode } from 'react'

import { FilterLink } from '../reports/list'
import { useQueryContext } from '../../query-context'
import { usePaginatedGetAPI } from '../../hooks/api-client'
import { rootRoute } from '../../router'
import { Order, OrderBy, useOrderBy } from '../../hooks/use-order-by'
import { Metric } from '../reports/metrics'
import { DashboardQuery } from '../../query'
import { SearchInput } from '../../components/search-input'
import { ColumnConfiguraton, Table } from '../../components/table'
import RocketIcon from './rocket-icon'

export const MIN_HEIGHT_PX = 500

// The main function component for rendering the "Details" reports on the dashboard,
// i.e. a breakdown by a single (non-time) dimension, with a given set of metrics.

// BreakdownModal is expected to be rendered inside a `<Modal>`, which has it's own
// specific URL pathname (e.g. /plausible.io/sources). During the lifecycle of a
// BreakdownModal, the `query` object is not expected to change.

// ### Search As You Type

// Debounces API requests when a search input changes and applies a `contains` filter
// on the given breakdown dimension (see the required `addSearchFilter` prop)

// ### Filter Links

// Dimension values can act as links back to the dashboard, where that specific value
// will be filtered by. (see the `getFilterInfo` required prop)

// ### Pagination

// By default, the component fetches `LIMIT` results. When exactly this number of
// results is received, a "Load More" button is rendered for fetching the next page
// of results.

// ### Required Props

//   * `reportInfo` - a map with the following required keys:

//        * `title` - the title of the report to render on the top left

//        * `endpoint` - the full pathname of the API endpoint to query. E.g.
//          `api/stats/plausible.io/sources`

//        * `dimensionLabel` - a string to render as the dimension column header.

//   * `metrics` - a list of `Metric` class objects which represent the columns
//     rendered in the report

//   * `getFilterInfo` - a function that takes a `listItem` and returns a map with
//     the necessary information to be able to link to a dashboard where that item
//     is filtered by. If a list item is not supposed to be a filter link, this
//     function should return `null` for that item.

// ### Optional Props

//   * `renderIcon` - a function that renders an icon for the given list item.

//   * `getExternalLinkURL` - a function that takes a list litem, and returns a
//     valid link href for this item. If the item is not supposed to be a link,
//     the function should return `null` for that item. Otherwise, if the returned
//     value exists, a small pop-out icon will be rendered whenever the list item
//     is hovered. When the icon is clicked, opens the external link in a new tab.

//   * `searchEnabled` - a boolean that determines if the search feature is enabled.
//     When true, the `addSearchFilter` function is expected. Is true by default.

//   * `addSearchFilter` - a function that takes a query object and a search string
//     as arguments, and returns a new `query` with an additional search filter.

//   * `afterFetchData` - a callback function taking an API response as an argument.
//     If this function is passed via props, it will be called after a successful
//     API response from the `fetchData` function.

//   * `afterFetchNextPage` - a function with the same behaviour as `afterFetchData`,
//     but will be called after a successful next page load in `fetchNextPage`.

export default function BreakdownModal<TListItem extends { name: string }>({
  reportInfo,
  metrics,
  renderIcon,
  getExternalLinkURL,
  searchEnabled = true,
  afterFetchData,
  afterFetchNextPage,
  addSearchFilter,
  getFilterInfo
}: {
  reportInfo: {
    title: string
    endpoint: string
    dimensionLabel: string
    defaultOrder?: Order
  }
  metrics: Metric[]
  renderIcon: (listItem: TListItem) => ReactNode
  getExternalLinkURL: (listItem: TListItem) => string
  searchEnabled?: boolean
  afterFetchData?: (response: { results: TListItem[] }) => void
  afterFetchNextPage?: (response: { results: TListItem[] }) => void
  addSearchFilter?: (q: DashboardQuery, search: string) => DashboardQuery
  getFilterInfo: (listItem: TListItem) => unknown
}) {
  const { query } = useQueryContext()

  const [search, setSearch] = useState('')
  const { orderBy, orderByDictionary, toggleSortByMetric } = useOrderBy({
    metrics,
    defaultOrderBy: reportInfo.defaultOrder ? [reportInfo.defaultOrder] : []
  })

  const {
    data,
    hasNextPage,
    fetchNextPage,
    isFetchingNextPage,
    isFetching,
    isPending
  } = usePaginatedGetAPI<
    { results: Array<TListItem> },
    [string, { query: DashboardQuery; search: string; orderBy: OrderBy }]
  >({
    key: [reportInfo.endpoint, { query, search, orderBy }],
    getRequestParams: (key) => {
      const [_endpoint, { query, search }] = key

      let queryWithSearchFilter = { ...query }

      if (
        searchEnabled &&
        typeof addSearchFilter === 'function' &&
        search !== ''
      ) {
        queryWithSearchFilter = addSearchFilter(query, search)
      }

      return [
        queryWithSearchFilter,
        {
          detailed: true,
          order_by: JSON.stringify(orderBy)
        }
      ]
    },
    afterFetchData,
    afterFetchNextPage
  })

  function maybeRenderIcon(item: TListItem) {
    if (typeof renderIcon === 'function') {
      return renderIcon(item)
    }
  }

  function maybeRenderExternalLink(item: TListItem) {
    if (typeof getExternalLinkURL === 'function') {
      const linkUrl = getExternalLinkURL(item)

      if (!linkUrl) {
        return null
      }

      return (
        <a
          target="_blank"
          href={linkUrl}
          rel="noreferrer"
          className="hidden group-hover:block"
        >
          <svg
            className="inline h-4 w-4 ml-1 -mt-1 text-gray-600 dark:text-gray-400"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path>
            <path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path>
          </svg>
        </a>
      )
    }
  }

  function renderNameCell(item: TListItem) {
    return (
      <>
        {maybeRenderIcon(item)}
        <FilterLink
          path={rootRoute.path}
          filterInfo={getFilterInfo(item)}
          onClick={undefined}
          extraClass={undefined}
        >
          {item.name}
        </FilterLink>
        {maybeRenderExternalLink(item)}
      </>
    )
  }

  function renderInitialLoadingSpinner() {
    return (
      <div
        className="w-full h-full flex flex-col justify-center"
        style={{ minHeight: `${MIN_HEIGHT_PX}px` }}
      >
        <div className="mx-auto loading">
          <div></div>
        </div>
      </div>
    )
  }

  function renderSmallLoadingSpinner() {
    return (
      <div className="loading sm">
        <div></div>
      </div>
    )
  }

  function renderLoadMoreButton() {
    if (isPending) return null
    if (!isFetching && !hasNextPage) return null

    return (
      <div className="flex flex-col w-full my-4 items-center justify-center h-10">
        {!isFetching && (
          <button
            onClick={() => fetchNextPage()}
            type="button"
            className="button"
          >
            Load more
          </button>
        )}
        {isFetchingNextPage && renderSmallLoadingSpinner()}
      </div>
    )
  }

  function renderModalBody() {
    if (data?.pages?.length) {
      return (
        <main className="modal__content">
          <Table<TListItem>
            data={data}
            columns={[
              {
                key: 'name',
                accessor: 'name',
                width: 'w-48 md:w-80 flex items-center break-all',
                align: 'left',
                label: reportInfo.dimensionLabel,
                renderItem: renderNameCell
              },
              ...metrics.map(
                (m): ColumnConfiguraton<TListItem> => ({
                  key: m.key,
                  accessor: m.accessor,
                  width: m.width,
                  align: 'right',
                  label: m.renderLabel(query),
                  onSort: m.sortable ? () => toggleSortByMetric(m) : undefined,
                  sortDirection: orderByDictionary[m.key]
                })
              )
            ]}
          />
        </main>
      )
    }
  }

  return (
    <div className="w-full h-full">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-x-2">
          <h1 className="text-xl font-bold dark:text-gray-100">
            {reportInfo.title}
          </h1>
          {!isPending && isFetching && renderSmallLoadingSpinner()}
        </div>
        {searchEnabled && <SearchInput onSearch={setSearch} />}
      </div>
      <div className="my-4 border-b border-gray-300"></div>
      <div style={{ minHeight: `${MIN_HEIGHT_PX}px` }}>
        {isPending && renderInitialLoadingSpinner()}
        {!isPending && renderModalBody()}
        {renderLoadMoreButton()}
      </div>
    </div>
  )
}

const InitialLoadingSpinner = () => (
  <div
    className="w-full h-full flex flex-col justify-center"
    style={{ minHeight: `${MIN_HEIGHT_PX}px` }}
  >
    <div className="mx-auto loading">
      <div />
    </div>
  </div>
)

const SmallLoadingSpinner = () => (
  <div className="loading sm">
    <div />
  </div>
)

const ErrorMessage = ({ error }: { error?: unknown }) => (
  <div
    className="grid grid-rows-2 text-gray-700 dark:text-gray-300"
    style={{ height: `${MIN_HEIGHT_PX}px` }}
  >
    <div className="text-center self-end">
      <RocketIcon />
    </div>
    <div className="text-lg text-center">
      {error ? (error as { message: string }).message : 'Something went wrong'}
    </div>
  </div>
)

const LoadMore = ({ onClick }: { onClick: () => void }) => (
  <button onClick={onClick} type="button" className="button">
    Load more
  </button>
)

export const PaginatedSearchableTable = <TListItem extends { name: string }>({
  title,
  isPending,
  isFetching,
  onSearch,
  hasNextPage,
  isFetchingNextPage,
  fetchNextPage,
  columns,
  data,
  status,
  error,
  displayError
}: {
  title: ReactNode
  isPending: boolean
  isFetching: boolean
  onSearch?: (input: string) => void
  hasNextPage: boolean
  isFetchingNextPage: boolean
  fetchNextPage: () => void
  columns: ColumnConfiguraton<TListItem>[]
  data?: TListItem[] | { pages: TListItem[][] }
  status?: 'error'
  error?: Error
  displayError?: boolean
}) => (
  <div className="w-full h-full">
    <div className="flex justify-between items-center">
      <div className="flex items-center gap-x-2">
        <h1 className="text-xl font-bold dark:text-gray-100">{title}</h1>
        {!isPending && isFetching && <SmallLoadingSpinner />}
      </div>
      {!!onSearch && (
        <SearchInput
          onSearch={onSearch}
          className={
            displayError && status === 'error' ? 'pointer-events-none' : ''
          }
        />
      )}
    </div>
    <div className="my-4 border-b border-gray-300"></div>
    <div style={{ minHeight: `${MIN_HEIGHT_PX}px` }}>
      {displayError && status === 'error' && <ErrorMessage error={error} />}
      {isPending && <InitialLoadingSpinner />}
      {data && <Table<TListItem> data={data} columns={columns} />}
      {!isPending && !isFetching && hasNextPage && (
        <div className="flex flex-col w-full my-4 items-center justify-center h-10">
          {isFetchingNextPage ? (
            <SmallLoadingSpinner />
          ) : (
            <LoadMore onClick={() => fetchNextPage()} />
          )}
        </div>
      )}
    </div>
  </div>
)
