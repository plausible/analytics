/** @format */

import React, { useCallback, useMemo, useState } from 'react'
import {
  DropdownLinkGroup,
  DropdownNavigationLink,
  DropdownSubtitle
} from '../components/dropdown'
import { useQueryContext } from '../query-context'
import { useSiteContext } from '../site-context'
import {
  formatSegmentIdAsLabelKey,
  getFilterSegmentsByNameInsensitive,
  isSegmentFilter,
  parseApiSegmentData,
  SavedSegment,
  SegmentData,
  SegmentType
} from './segments'
import { QueryFunction, useQuery, useQueryClient } from '@tanstack/react-query'
import { cleanLabels } from '../util/filters'
import {
  AppNavigationLink,
  useAppNavigate
} from '../navigation/use-app-navigate'
import classNames from 'classnames'
import { Tooltip } from '../util/tooltip'
import { useUserContext } from '../user-context'
import { ChevronLeftIcon, ChevronRightIcon } from '@heroicons/react/24/solid'
import {
  SegmentExpandedLocationState,
  useSegmentExpandedContext
} from './segment-expanded-context'
import { filterRoute, rootRoute } from '../router'
import { SearchInput } from '../components/search-input'
import { SegmentAuthorship } from './segment-authorship'

export const useSegmentsListQuery = () => {
  const site = useSiteContext()
  return useQuery({
    queryKey: ['segments'],
    placeholderData: (previousData) => previousData,
    queryFn: async () => {
      const response = await fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments`,
        {
          method: 'GET',
          headers: {
            'content-type': 'application/json',
            accept: 'application/json'
          }
        }
      ).then(
        (
          res
        ): Promise<
          (SavedSegment & {
            owner_id: number
            inserted_at: string
            updated_at: string
          })[]
        > => res.json()
      )
      return response
    }
  })
}

const linkClass = 'text-xs'

export const SegmentsList = ({ closeList }: { closeList: () => void }) => {
  const { expandedSegment } = useSegmentExpandedContext()
  const { query } = useQueryContext()

  const { data } = useSegmentsListQuery()

  const segmentFilter = query.filters.find(isSegmentFilter)
  const appliedSegmentIds = (segmentFilter ? segmentFilter[2] : []) as number[]

  const [search, setSearch] = useState<string>()

  if (expandedSegment) {
    return (
      <>
        <AppNavigationLink
          className="flex text-xs px-4 py-2 gap-1 bg-gray-50 dark:bg-gray-900 rounded-t-md"
          search={(s) => ({
            ...s,
            filters: [['is', 'segment', [expandedSegment.id]]],
            labels: {
              [formatSegmentIdAsLabelKey(expandedSegment.id)]:
                expandedSegment.name
            }
          })}
          state={
            {
              expandedSegment: null,
              modal: null
            } as SegmentExpandedLocationState
          }
          // onClick={closeList}
        >
          {/* <XMarkIcon className="block h-4 w-4" /> */}
          <ChevronLeftIcon className="block h-4 w-4"></ChevronLeftIcon>
          <div>Back to filters</div>
        </AppNavigationLink>
        <DropdownLinkGroup>
          <DropdownSubtitle className="break-all">
            {expandedSegment.name}
          </DropdownSubtitle>
          <DropdownNavigationLink
            className={linkClass}
            search={(s) => s}
            navigateOptions={{
              state: {
                expandedSegment: expandedSegment,
                modal: 'update'
              } as SegmentExpandedLocationState
            }}
          >
            Update segment
          </DropdownNavigationLink>
          <DropdownNavigationLink
            className={linkClass}
            search={(s) => s}
            navigateOptions={{
              state: {
                expandedSegment: expandedSegment,
                modal: 'create'
              } as SegmentExpandedLocationState
            }}
          >
            Save as a new segment
          </DropdownNavigationLink>
          <DropdownNavigationLink
            className={linkClass}
            search={(s) => s}
            navigateOptions={{
              state: {
                expandedSegment: expandedSegment,
                modal: 'delete'
              } as SegmentExpandedLocationState
            }}
          >
            Delete segment
          </DropdownNavigationLink>
        </DropdownLinkGroup>
      </>
    )
  }

  const filteredData = data?.filter(getFilterSegmentsByNameInsensitive(search))

  const personalSegments = filteredData?.filter(
    (i) => i.type === SegmentType.personal
  )
  const siteSegments = filteredData?.filter((i) => i.type === SegmentType.site)

  return (
    <>
      {!!data?.length && (
        <DropdownLinkGroup>
          <DropdownSubtitle>Segments</DropdownSubtitle>

          <div className="px-4 py-1">
            <SearchInput
              className="w-full text-xs sm:text-xs"
              onSearch={setSearch}
            />
          </div>
          {[
            { segments: personalSegments, title: 'Personal' },
            { segments: siteSegments, title: 'Site' }
          ]
            .filter((i) => !!i.segments?.length)
            .map(({ segments, title }) => (
              <>
                <DropdownSubtitle className="normal-case">
                  {title}
                </DropdownSubtitle>

                {segments!.slice(0, 3).map((s) => {
                  return (
                    <Tooltip
                      key={s.id}
                      info={
                        <div className="max-w-60">
                          <div className="break-all">{s.name}</div>
                          <SegmentAuthorship
                            {...s}
                            className="font-normal text-xs"
                          />
                        </div>
                      }
                    >
                      <SegmentLink
                        {...s}
                        appliedSegmentIds={appliedSegmentIds}
                        closeList={closeList}
                      />
                    </Tooltip>
                  )
                })}
              </>
            ))}
          {!!data?.length && (
            <DropdownNavigationLink
              className={classNames(
                linkClass,
                'font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
              )}
              path={filterRoute.path}
              params={{ field: 'segment' }}
              search={(s) => s}
              onLinkClick={closeList}
            >
              View all
              <ChevronRightIcon className="block w-4 h-4" />
            </DropdownNavigationLink>
          )}
        </DropdownLinkGroup>
      )}
      <DropdownLinkGroup>
        <SaveSelectionAsSegment closeList={closeList} />
        {/* <DropdownNavigationLink
          className={classNames(linkClass, 'font-bold')}
          search={(s) => s}
          navigateOptions={{
            state: {
              modal: 'create',
              expandedSegment: null
            } as SegmentExpandedLocationState
          }}
          onLinkClick={closeList}
          {...((query.filters.some(isSegmentFilter) ||
            !query.filters.length) && {
            'aria-disabled': true,
            navigateOptions: undefined,
            onLinkClick: undefined
          })}
        >
          Save selection as segment
        </DropdownNavigationLink> */}
      </DropdownLinkGroup>
    </>
  )
}

const SaveSelectionAsSegment = ({ closeList }: { closeList: () => void }) => {
  const { query } = useQueryContext()
  const disabledReason = !query.filters.length
    ? 'Add filters to the dashboard to save a segment.'
    : query.filters.some(isSegmentFilter)
      ? 'Remove the segment filter to save a segment. Segments can not contain other segments.'
      : null
  if (disabledReason === null) {
    return (
      <DropdownNavigationLink
        className={classNames(
          linkClass,
          'font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
        )}
        search={(s) => s}
        navigateOptions={{
          state: {
            modal: 'create',
            expandedSegment: null
          } as SegmentExpandedLocationState
        }}
        onLinkClick={closeList}
      >
        Save as segment
      </DropdownNavigationLink>
    )
  }

  return (
    <Tooltip info={<div className="max-w-60">{disabledReason}</div>}>
      <DropdownNavigationLink
        className={classNames(linkClass, 'font-bold')}
        search={(s) => s}
        aria-disabled={true}
      >
        Save as segment
      </DropdownNavigationLink>
    </Tooltip>
  )
}

export const useSegmentPrefetch = ({ id }: Pick<SavedSegment, 'id'>) => {
  const site = useSiteContext()
  const queryClient = useQueryClient()
  const queryKey = useMemo(() => ['segments', id] as const, [id])
  const navigate = useAppNavigate()

  const getSegmentFn: QueryFunction<
    { segment_data: SegmentData } & SavedSegment,
    typeof queryKey
  > = useCallback(
    async ({ queryKey: [_, id] }) => {
      const res = await fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments/${id}`,
        {
          method: 'GET',
          headers: {
            'content-type': 'application/json',
            accept: 'application/json'
          }
        }
      )
      const d = await res.json()
      return {
        ...d,
        segment_data: parseApiSegmentData(d.segment_data)
      }
    },
    [site]
  )

  const getSegment = useQuery({
    enabled: false,
    queryKey: queryKey,
    queryFn: getSegmentFn
  })

  const prefetchSegment = useCallback(
    () =>
      queryClient.prefetchQuery({
        queryKey,
        queryFn: getSegmentFn,
        staleTime: 120_000
      }),
    [queryClient, getSegmentFn, queryKey]
  )

  const fetchSegment = useCallback(
    () =>
      queryClient.fetchQuery({
        queryKey,
        queryFn: getSegmentFn
      }),
    [queryClient, getSegmentFn, queryKey]
  )

  const expandSegment = useCallback(
    (segment: SavedSegment & { segment_data: SegmentData }) => {
      try {
        navigate({
          path: rootRoute.path,
          search: (search) => ({
            ...search,
            filters: segment.segment_data.filters,
            labels: segment.segment_data.labels
          }),
          state: {
            expandedSegment: {
              id: segment.id,
              name: segment.name,
              type: segment.type,
              owner_id: segment.owner_id
            }
          } as SegmentExpandedLocationState
        })
      } catch (_error) {
        return
      }
    },
    [navigate]
  )

  return { prefetchSegment, data: getSegment.data, fetchSegment, expandSegment }
}

const SegmentLink = ({
  id,
  name,
  // type,
  // owner_id,
  appliedSegmentIds
  // closeList
}: SavedSegment & { appliedSegmentIds: number[]; closeList: () => void }) => {
  const user = useUserContext()
  const canSeeActions = user.loggedIn
  // const canDeleteSegment =
  //   user.loggedIn &&
  //   ((owner_id === user.id && type === SegmentType.personal) ||
  //     (type === SegmentType.site &&
  //       ['admin', 'owner', 'super_admin'].includes(user.role)))
  const { query } = useQueryContext()
  const { prefetchSegment, expandSegment, data, fetchSegment } =
    useSegmentPrefetch({ id })

  return (
    <DropdownNavigationLink
      className={linkClass}
      key={id}
      active={appliedSegmentIds.includes(id)}
      onMouseEnter={prefetchSegment}
      navigateOptions={{
        state: { expandedSegment: null } as SegmentExpandedLocationState
      }}
      search={(search) => {
        const otherFilters = query.filters.filter((f) => !isSegmentFilter(f))
        const updatedSegmentIds = appliedSegmentIds.includes(id)
          ? appliedSegmentIds.filter((i) => i !== id)
          : [...appliedSegmentIds, id]

        if (!updatedSegmentIds.length) {
          return {
            ...search,
            filters: otherFilters,
            labels: cleanLabels(otherFilters, query.labels)
          }
        }

        const updatedFilters = [
          ['is', 'segment', updatedSegmentIds],
          ...otherFilters
        ]

        return {
          ...search,
          filters: updatedFilters,
          labels: cleanLabels(updatedFilters, query.labels, 'segment', {
            [formatSegmentIdAsLabelKey(id)]: name
          })
        }
      }}
      actions={
        !canSeeActions ? null : (
          <>
            <EditSegment
              className="ml-2 shrink-0"
              onClick={async () =>
                expandSegment(data ?? (await fetchSegment()))
              }
            />
          </>
        )
      }
    >
      <div className="truncate">{name}</div>
    </DropdownNavigationLink>
  )
}

export const EditSegment = ({
  className,
  onClick,
  onMouseEnter
}: {
  onClick: () => Promise<void>
  onMouseEnter?: () => Promise<void>
  className?: string
}) => {
  return (
    <button
      className={classNames(
        'block w-4 h-4 fill-current hover:fill-indigo-600',
        className
      )}
      onClick={onClick}
      onMouseEnter={onMouseEnter}
    >
      {/* <ChevronRightIcon className="w-4 h-4"></ChevronRightIcon> */}
      <EditSegmentIcon className="w-4 h-4" />
    </button>
  )
}

const EditSegmentIcon = ({ className }: { className?: string }) => (
  <svg
    className={className}
    viewBox="0 0 16 16"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path d="M14.2075 4.58572L11.4144 1.79322C11.3215 1.70034 11.2113 1.62666 11.0899 1.57639C10.9686 1.52612 10.8385 1.50024 10.7072 1.50024C10.5759 1.50024 10.4458 1.52612 10.3245 1.57639C10.2031 1.62666 10.0929 1.70034 10 1.79322L2.29313 9.50009C2.19987 9.59262 2.12593 9.70275 2.0756 9.82411C2.02528 9.94546 1.99959 10.0756 2.00001 10.207V13.0001C2.00001 13.2653 2.10536 13.5197 2.2929 13.7072C2.48043 13.8947 2.73479 14.0001 3 14.0001H13.5C13.6326 14.0001 13.7598 13.9474 13.8536 13.8536C13.9473 13.7599 14 13.6327 14 13.5001C14 13.3675 13.9473 13.2403 13.8536 13.1465C13.7598 13.0528 13.6326 13.0001 13.5 13.0001H7.2075L14.2075 6.00009C14.3004 5.90723 14.3741 5.79698 14.4243 5.67564C14.4746 5.5543 14.5005 5.42425 14.5005 5.29291C14.5005 5.16156 14.4746 5.03151 14.4243 4.91017C14.3741 4.78883 14.3004 4.67858 14.2075 4.58572ZM5.79313 13.0001H3V10.207L8.5 4.70697L11.2931 7.50009L5.79313 13.0001ZM12 6.79322L9.20751 4.00009L10.7075 2.50009L13.5 5.29322L12 6.79322Z" />
  </svg>
)
