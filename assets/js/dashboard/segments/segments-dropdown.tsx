/** @format */

import React, { useCallback, useMemo } from 'react'
import {
  DropdownLinkGroup,
  DropdownNavigationLink
} from '../components/dropdown'
import { useQueryContext } from '../query-context'
import { useSiteContext } from '../site-context'
import {
  formatSegmentIdAsLabelKey,
  isSegmentFilter,
  parseApiSegmentData,
  SavedSegment,
  SegmentData,
  SegmentType
} from './segments'
import { QueryFunction, useQuery, useQueryClient } from '@tanstack/react-query'
import { cleanLabels } from '../util/filters'
import { useAppNavigate } from '../navigation/use-app-navigate'
import classNames from 'classnames'
import { Tooltip } from '../util/tooltip'
import { formatDayShort, parseUTCDate } from '../util/date'
import { useUserContext } from '../user-context'
import {
  ArrowsPointingInIcon,
  ArrowsPointingOutIcon,
  ChevronRightIcon
} from '@heroicons/react/24/solid'
import {
  SegmentExpandedLocationState,
  useSegmentExpandedContext
} from './segment-expanded-context'
import { filterRoute, rootRoute } from '../router'

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

export const SegmentsList = ({ closeList }: { closeList: () => void }) => {
  const { expandedSegment } = useSegmentExpandedContext()
  const { query } = useQueryContext()
  const site = useSiteContext()

  const { data } = useSegmentsListQuery()

  const segmentFilter = query.filters.find(isSegmentFilter)
  const appliedSegmentIds = (segmentFilter ? segmentFilter[2] : []) as number[]

  if (expandedSegment) {
    return (
      <>
        <DropdownLinkGroup>
          <DropdownNavigationLink
            search={(s) => ({ ...s, filters: null, labels: null })}
            active={true}
            navigateOptions={{
              state: {
                expandedSegment: null,
                modal: null
              } as SegmentExpandedLocationState
            }}
          >
            <div className="truncate">{expandedSegment.name}</div>
            <ArrowsPointingInIcon className="w-4 h-4 shrink-0" />
          </DropdownNavigationLink>
          <DropdownNavigationLink
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

  return (
    <>
      {!!data?.length && (
        <DropdownLinkGroup>
          {data.slice(0, 4).map((s) => {
            const authorLabel = (() => {
              if (!site.members) {
                return ''
              }

              if (!s.owner_id || !site.members[s.owner_id]) {
                return '(Removed User)'
              }

              // if (s.owner_id === user.id) {
              //   return 'You'
              // }

              return site.members[s.owner_id]
            })()

            const showUpdatedAt = s.updated_at !== s.inserted_at

            return (
              <Tooltip
                key={s.id}
                info={
                  <div>
                    <div>
                      {
                        {
                          [SegmentType.personal]: 'Personal segment',
                          [SegmentType.site]: 'Segment'
                        }[s.type]
                      }
                    </div>
                    <div className="font-normal text-xs">
                      {`Created at ${formatDayShort(parseUTCDate(s.inserted_at))}`}
                      {!showUpdatedAt && !!authorLabel && ` by ${authorLabel}`}
                    </div>
                    {showUpdatedAt && (
                      <div className="font-normal text-xs">
                        {`Last updated at ${formatDayShort(parseUTCDate(s.updated_at))}`}
                        {!!authorLabel && ` by ${authorLabel}`}
                      </div>
                    )}
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
          <DropdownNavigationLink
            path={filterRoute.path}
            params={{ field: 'segment' }}
            search={(s) => s}
            onLinkClick={closeList}
          >
            View all <ChevronRightIcon className="h-4 w-4" />
          </DropdownNavigationLink>
        </DropdownLinkGroup>
      )}
    </>
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

  const expandSegment = useCallback(async () => {
    try {
      const data = getSegment.data ?? (await fetchSegment())
      navigate({
        path: rootRoute.path,
        search: (search) => ({
          ...search,
          filters: data.segment_data.filters,
          labels: data.segment_data.labels
        }),
        state: {
          expandedSegment: {
            id: data.id,
            name: data.name,
            type: data.type,
            owner_id: data.owner_id
          }
        } as SegmentExpandedLocationState
      })
    } catch (_error) {
      return
    }
  }, [fetchSegment, getSegment.data, navigate])

  return { prefetchSegment, expandSegment }
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
  const { prefetchSegment, expandSegment } = useSegmentPrefetch({ id })

  return (
    <DropdownNavigationLink
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
            <ExpandSegment className="ml-2 shrink-0" onClick={expandSegment} />
          </>
        )
      }
    >
      <div className="truncate">{name}</div>
    </DropdownNavigationLink>
  )
}

const ExpandSegment = ({
  className,
  onClick
}: {
  onClick: () => Promise<void>
  className?: string
}) => {
  return (
    <button
      className={classNames(
        'block w-4 h-4 fill-current hover:fill-indigo-600',
        className
      )}
      onClick={onClick}
    >
      <ArrowsPointingOutIcon />
    </button>
  )
}
