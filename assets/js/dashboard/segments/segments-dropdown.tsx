/** @format */

import React from 'react'
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
  ArrowsPointingOutIcon
} from '@heroicons/react/24/solid'
import {
  SegmentExpandedLocationState,
  useSegmentExpandedContext
} from './segment-expanded-context'

export const SegmentsList = ({ closeList }: { closeList: () => void }) => {
  const { expandedSegment } = useSegmentExpandedContext()
  const { query } = useQueryContext()
  const site = useSiteContext()

  const { data } = useQuery({
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
            {expandedSegment.name}
            <ArrowsPointingInIcon className="w-4 h-4" />
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
          {data.map((s) => {
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
        </DropdownLinkGroup>
      )}
    </>
  )
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
  const site = useSiteContext()
  const { query } = useQueryContext()
  const queryClient = useQueryClient()

  const queryKey = ['segments', id] as const

  const getSegmentFn: QueryFunction<
    { segment_data: SegmentData } & SavedSegment,
    typeof queryKey
  > = async ({ queryKey: [_, id] }) => {
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
  }

  const navigate = useAppNavigate()

  const getSegment = useQuery({
    enabled: false,
    queryKey: queryKey,
    queryFn: getSegmentFn
  })

  const prefetchSegment = () =>
    queryClient.prefetchQuery({
      queryKey,
      queryFn: getSegmentFn,
      staleTime: 120_000
    })

  const fetchSegment = () =>
    queryClient.fetchQuery({
      queryKey,
      queryFn: getSegmentFn
    })

  const editSegment = async () => {
    try {
      const data = getSegment.data ?? (await fetchSegment())
      navigate({
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
  }

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
            <ExpandSegment className="ml-2" onClick={editSegment} />
          </>
        )
      }
    >
      {name}
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