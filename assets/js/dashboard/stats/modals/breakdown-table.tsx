import React, { ReactNode, useRef } from 'react'

import { SearchInput } from '../../components/search-input'
import { ColumnConfiguraton, Table } from '../../components/table'
import RocketIcon from './rocket-icon'
import { QueryStatus } from '@tanstack/react-query'

const MIN_HEIGHT_PX = 500

export const BreakdownTable = <TListItem extends { name: string }>({
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
  onSearch?: (input: string) => void
  isPending: boolean
  isFetching: boolean
  hasNextPage: boolean
  isFetchingNextPage: boolean
  fetchNextPage: () => void
  columns: ColumnConfiguraton<TListItem>[]
  data?: { pages: TListItem[][] }
  status?: QueryStatus
  error?: Error | null
  /** Controls whether the component displays API request errors or ignores them. */
  displayError?: boolean
}) => {
  const searchRef = useRef<HTMLInputElement>(null)

  return (
    <div className="w-full h-full">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-x-2">
          <h1 className="text-xl font-bold dark:text-gray-100">{title}</h1>
          {!isPending && isFetching && <SmallLoadingSpinner />}
        </div>
        {!!onSearch && (
          <SearchInput
            searchRef={searchRef}
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
          <LoadMore
            onClick={() => fetchNextPage()}
            isFetchingNextPage={isFetchingNextPage}
          />
        )}
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
      {error
        ? (error as { message: string }).message
        : 'Error loading data. Refresh the page to try again'}
    </div>
  </div>
)

const LoadMore = ({
  onClick,
  isFetchingNextPage
}: {
  onClick: () => void
  isFetchingNextPage: boolean
}) => (
  <div className="flex flex-col w-full my-4 items-center justify-center h-10">
    {isFetchingNextPage ? (
      <SmallLoadingSpinner />
    ) : (
      <button onClick={onClick} type="button" className="button">
        Load more
      </button>
    )}
  </div>
)
