import React, { ReactNode, useRef } from 'react'
import { XMarkIcon } from '@heroicons/react/20/solid'

import { SearchInput } from '../../components/search-input'
import { ColumnConfiguraton, Table } from '../../components/table'
import RocketIcon from './rocket-icon'
import { QueryStatus } from '@tanstack/react-query'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { rootRoute } from '../../router'

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
  displayError,
  onClose
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
  onClose?: () => void
}) => {
  const searchRef = useRef<HTMLInputElement>(null)
  const navigate = useAppNavigate()
  const handleClose =
    onClose ?? (() => navigate({ path: rootRoute.path, search: (s) => s }))

  return (
    <>
      <div className="flex justify-between items-center gap-4">
        <div className="flex items-center gap-4 w-full">
          <h1 className="shrink-0 mb-0.5 text-base md:text-lg font-bold dark:text-gray-100">
            {title}
          </h1>
          {!!onSearch && (
            <SearchInput
              searchRef={searchRef}
              onSearch={onSearch}
              className={
                displayError && status === 'error'
                  ? '[&_input]:pointer-events-none'
                  : ''
              }
            />
          )}
          {!isPending && isFetching && <SmallLoadingSpinner />}
        </div>
        <button
          type="button"
          onClick={handleClose}
          aria-label="Close modal"
          className="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
        >
          <XMarkIcon className="size-5" />
        </button>
      </div>
      <div className="my-3 md:my-4 border-b border-gray-250 dark:border-gray-750"></div>
      <div className="flex-1 overflow-auto pr-4 -mr-4">
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
    </>
  )
}

const InitialLoadingSpinner = () => (
  <div className="w-full h-full flex flex-col justify-center">
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
  <div className="grid grid-rows-2 text-gray-700 dark:text-gray-300">
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
