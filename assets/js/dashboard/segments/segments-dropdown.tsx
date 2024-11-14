/** @format */

import React from 'react'
import {
  DropdownLinkGroup,
  DropdownNavigationLink
} from '../components/dropdown'
import { useQueryContext } from '../query-context'
import { useSiteContext } from '../site-context'
import {
  EditingSegmentState,
  formatSegmentIdAsLabelKey,
  isSegmentFilter,
  parseApiSegmentData,
  SavedSegment,
  SegmentData,
  SegmentType
} from './segments'
import {
  QueryFunction,
  useMutation,
  useQuery,
  useQueryClient
} from '@tanstack/react-query'
import { cleanLabels } from '../util/filters'
import { useAppNavigate } from '../navigation/use-app-navigate'
import classNames from 'classnames'
import { Tooltip } from '../util/tooltip'
import { formatDayShort, parseUTCDate } from '../util/date'
import { useUserContext } from '../user-context'

export const SegmentsList = ({ closeList }: { closeList: () => void }) => {
  // const user = useUserContext();
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

  return (
    !!data?.length && (
      <DropdownLinkGroup>
        {data.map((s) => {
          const authorLabel = (() => {
            if (!site.members) {
              return ''
            }

            if (!s.owner_id || !site.members[s.owner_id]) {
              return '(Deleted User)'
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
    )
  )
}

const SegmentLink = ({
  id,
  name,
  type,
  owner_id,
  appliedSegmentIds,
  closeList
}: SavedSegment & { appliedSegmentIds: number[]; closeList: () => void }) => {
  const user = useUserContext()
  const canSeeActions = user.loggedIn
  const canDeleteSegment =
    user.loggedIn &&
    ((owner_id === user.id && type === SegmentType.personal) ||
      (type === SegmentType.site &&
        ['admin', 'owner', 'super_admin'].includes(user.role)))
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
          editingSegment: {
            id: data.id,
            name: data.name,
            type: data.type,
            owner_id: data.owner_id
          }
        } as EditingSegmentState
      })
      closeList()
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
        state: { editingSegment: null } as EditingSegmentState
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
            <EditSegment className="ml-2" onClick={editSegment} />
            <DeleteSegment
              disabled={!canDeleteSegment}
              className="ml-2"
              segment={{ id, name, type, owner_id }}
            />
          </>
        )
      }
    >
      {name}
    </DropdownNavigationLink>
  )
}

const EditSegment = ({
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
      <EditSegmentIcon />
    </button>
  )
}

const DeleteSegment = ({
  disabled,
  className,
  segment
}: {
  disabled?: boolean
  className?: string
  segment: SavedSegment
}) => {
  const queryClient = useQueryClient()
  const site = useSiteContext()
  const navigate = useAppNavigate()
  const { query } = useQueryContext()
  const deleteSegment = useMutation({
    mutationFn: (data: SavedSegment) => {
      return fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments/${data.id}`,
        {
          method: 'DELETE'
        }
      )
        .then((res) => res.json())
        .then((d) => ({
          ...d,
          segment_data: parseApiSegmentData(d.segment_data)
        }))
    },
    onSuccess: (_d): void => {
      queryClient.invalidateQueries({ queryKey: ['segments'] })

      const segmentFilterIndex = query.filters.findIndex(isSegmentFilter)
      if (segmentFilterIndex < 0) {
        return
      }

      const filter = query.filters[segmentFilterIndex]
      const clauses = filter[2]
      const updatedSegmentIds = clauses.filter((c) => c !== segment.id)

      if (updatedSegmentIds.length === clauses.length) {
        return
      }

      const newFilters = !updatedSegmentIds.length
        ? query.filters.filter((_f, index) => index !== segmentFilterIndex)
        : [
            ...query.filters.slice(0, segmentFilterIndex),
            [filter[0], filter[1], updatedSegmentIds],
            ...query.filters.slice(segmentFilterIndex + 1)
          ]

      navigate({
        search: (s) => {
          return {
            ...s,
            filters: newFilters,
            labels: cleanLabels(newFilters, query.labels)
          }
        }
      })
    }
  })

  return (
    <button
      disabled={disabled}
      className={classNames(
        'block w-4 h-4 fill-current hover:fill-red-600',
        className
      )}
      title="Delete segment"
      onClick={disabled ? () => {} : () => deleteSegment.mutate(segment)}
    >
      <DeleteSegmentIcon />
    </button>
  )
}

const DeleteSegmentIcon = () => (
  <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
    <path d="M12.8535 12.1463C12.9 12.1927 12.9368 12.2479 12.962 12.3086C12.9871 12.3693 13.0001 12.4343 13.0001 12.5C13.0001 12.5657 12.9871 12.6308 12.962 12.6915C12.9368 12.7522 12.9 12.8073 12.8535 12.8538C12.8071 12.9002 12.7519 12.9371 12.6912 12.9622C12.6305 12.9874 12.5655 13.0003 12.4998 13.0003C12.4341 13.0003 12.369 12.9874 12.3083 12.9622C12.2476 12.9371 12.1925 12.9002 12.146 12.8538L7.99979 8.70691L3.85354 12.8538C3.75972 12.9476 3.63247 13.0003 3.49979 13.0003C3.36711 13.0003 3.23986 12.9476 3.14604 12.8538C3.05222 12.76 2.99951 12.6327 2.99951 12.5C2.99951 12.3674 3.05222 12.2401 3.14604 12.1463L7.29291 8.00003L3.14604 3.85378C3.05222 3.75996 2.99951 3.63272 2.99951 3.50003C2.99951 3.36735 3.05222 3.2401 3.14604 3.14628C3.23986 3.05246 3.36711 2.99976 3.49979 2.99976C3.63247 2.99976 3.75972 3.05246 3.85354 3.14628L7.99979 7.29316L12.146 3.14628C12.2399 3.05246 12.3671 2.99976 12.4998 2.99976C12.6325 2.99976 12.7597 3.05246 12.8535 3.14628C12.9474 3.2401 13.0001 3.36735 13.0001 3.50003C13.0001 3.63272 12.9474 3.75996 12.8535 3.85378L8.70666 8.00003L12.8535 12.1463Z" />
  </svg>
)

const EditSegmentIcon = () => (
  <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
    <path d="M14.2075 4.58572L11.4144 1.79322C11.3215 1.70034 11.2113 1.62666 11.0899 1.57639C10.9686 1.52612 10.8385 1.50024 10.7072 1.50024C10.5759 1.50024 10.4458 1.52612 10.3245 1.57639C10.2031 1.62666 10.0929 1.70034 10 1.79322L2.29313 9.50009C2.19987 9.59262 2.12593 9.70275 2.0756 9.82411C2.02528 9.94546 1.99959 10.0756 2.00001 10.207V13.0001C2.00001 13.2653 2.10536 13.5197 2.2929 13.7072C2.48043 13.8947 2.73479 14.0001 3 14.0001H13.5C13.6326 14.0001 13.7598 13.9474 13.8536 13.8536C13.9473 13.7599 14 13.6327 14 13.5001C14 13.3675 13.9473 13.2403 13.8536 13.1465C13.7598 13.0528 13.6326 13.0001 13.5 13.0001H7.2075L14.2075 6.00009C14.3004 5.90723 14.3741 5.79698 14.4243 5.67564C14.4746 5.5543 14.5005 5.42425 14.5005 5.29291C14.5005 5.16156 14.4746 5.03151 14.4243 4.91017C14.3741 4.78883 14.3004 4.67858 14.2075 4.58572ZM5.79313 13.0001H3V10.207L8.5 4.70697L11.2931 7.50009L5.79313 13.0001ZM12 6.79322L9.20751 4.00009L10.7075 2.50009L13.5 5.29322L12 6.79322Z" />
  </svg>
)
