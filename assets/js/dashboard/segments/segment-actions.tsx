/** @format */

import React, { useState, useCallback } from 'react'
import { useAppNavigate } from '../navigation/use-app-navigate'
import { useQueryContext } from '../query-context'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { DashboardQuery } from '../query'
import { useSiteContext } from '../site-context'
import {
  cleanLabels,
  plainFilterText,
  remapToApiFilters
} from '../util/filters'
import {
  EditingSegmentState,
  formatSegmentIdAsLabelKey,
  parseApiSegmentData,
  SavedSegment,
  SegmentType
} from './segments'
import { CreateSegmentModal, UpdateSegmentModal } from './segment-modals'
import { useUserContext } from '../user-context'

type M = 'create segment' | 'update segment'
type O =
  | { type: 'create segment' }
  | { type: 'update segment'; segment: SavedSegment }

export const SaveSegmentAction = ({ options }: { options: O[] }) => {
  const user = useUserContext()
  const site = useSiteContext()
  const { query } = useQueryContext()
  const [modal, setModal] = useState<M | null>(null)
  const navigate = useAppNavigate()
  const openCreateSegment = useCallback(() => {
    return setModal('create segment')
  }, [])
  const openUpdateSegment = useCallback(() => {
    return setModal('update segment')
  }, [])
  const close = useCallback(() => {
    return setModal(null)
  }, [])
  const queryClient = useQueryClient()
  const createSegment = useMutation({
    mutationFn: ({
      name,
      type,
      segment_data
    }: {
      name: string
      type: 'personal' | 'site'
      segment_data: {
        filters: DashboardQuery['filters']
        labels: DashboardQuery['labels']
      }
    }) => {
      return fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments`,
        {
          method: 'POST',
          body: JSON.stringify({
            name,
            type,
            segment_data: {
              filters: remapToApiFilters(segment_data.filters),
              labels: cleanLabels(segment_data.filters, segment_data.labels)
            }
          }),
          headers: { 'content-type': 'application/json' }
        }
      )
        .then((res) => res.json())
        .then((d) => ({
          ...d,
          segment_data: parseApiSegmentData(d.segment_data)
        }))
    },
    onSuccess: async (d) => {
      navigate({
        search: (search) => {
          const filters = [['is', 'segment', [d.id]]]
          const labels = cleanLabels(filters, {}, 'segment', {
            [formatSegmentIdAsLabelKey(d.id)]: d.name
          })
          return {
            ...search,
            filters,
            labels
          }
        },
        state: { editingSegment: null } as EditingSegmentState
      })
      close()
      queryClient.invalidateQueries({ queryKey: ['segments'] })
    }
  })

  const patchSegment = useMutation({
    mutationFn: ({
      id,
      name,
      type,
      segment_data
    }: {
      id: number
      name?: string
      type?: SegmentType
      segment_data?: {
        filters: DashboardQuery['filters']
        labels: DashboardQuery['labels']
      }
    }) => {
      return fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments/${id}`,
        {
          method: 'PATCH',
          body: JSON.stringify({
            name,
            type,
            ...(segment_data && {
              segment_data: {
                filters: remapToApiFilters(segment_data.filters),
                labels: cleanLabels(segment_data.filters, segment_data.labels)
              }
            })
          }),
          headers: {
            'content-type': 'application/json',
            accept: 'application/json'
          }
        }
      )
        .then((res) => res.json())
        .then((d) => ({
          ...d,
          segment_data: parseApiSegmentData(d.segment_data)
        }))
    },
    onSuccess: async (d) => {
      navigate({
        search: (search) => {
          const filters = [['is', 'segment', [d.id]]]
          const labels = cleanLabels(filters, {}, 'segment', {
            [formatSegmentIdAsLabelKey(d.id)]: d.name
          })
          return {
            ...search,
            filters,
            labels
          }
        },
        state: { editingSegment: null } as EditingSegmentState
      })
      close()
      queryClient.invalidateQueries({ queryKey: ['segments'] })
    }
  })

  if (!user.loggedIn) {
    return null
  }

  const segmentNamePlaceholder = query.filters.reduce(
    (combinedName, filter) =>
      combinedName.length > 100
        ? combinedName
        : `${combinedName}${combinedName.length ? ' and ' : ''}${plainFilterText(query, filter)}`,
    ''
  )

  const option = options.find((o) => o.type === modal)
  const buttonClass =
    'whitespace-nowrap rounded font-semibold text-sm leading-tight p-2 h-9 text-gray-500 hover:text-indigo-700 dark:hover:text-indigo-500 disabled:cursor-not-allowed'
  return (
    <div className="flex gap-x-2">
      {options.map((o) => {
        if (o.type === 'create segment') {
          return (
            <button
              key={o.type}
              className={buttonClass}
              onClick={openCreateSegment}
            >
              {options.find((o) => o.type === 'update segment')
                ? 'Save as new segment'
                : 'Save as segment'}
            </button>
          )
        }
        if (o.type === 'update segment') {
          const canEdit =
            (o.segment.type === SegmentType.personal &&
              o.segment.owner_id === user.id) ||
            (o.segment.type === SegmentType.site &&
              ['admin', 'owner', 'super_admin'].includes(user.role))

          return (
            <button
              disabled={!canEdit}
              key={o.type}
              className={buttonClass}
              onClick={openUpdateSegment}
            >
              Update segment
            </button>
          )
        }
      })}
      {modal === 'create segment' && (
        <CreateSegmentModal
          canTogglePersonal={['admin', 'owner', 'super_admin'].includes(
            user.role
          )}
          segment={options.find((o) => o.type === 'update segment')?.segment}
          namePlaceholder={segmentNamePlaceholder}
          close={close}
          onSave={({ name, type }) =>
            createSegment.mutate({
              name,
              type,
              segment_data: {
                filters: query.filters,
                labels: query.labels
              }
            })
          }
        />
      )}
      {option?.type === 'update segment' && (
        <UpdateSegmentModal
          canTogglePersonal={['admin', 'owner', 'super_admin'].includes(
            user.role
          )}
          segment={option.segment}
          namePlaceholder={segmentNamePlaceholder}
          close={close}
          onSave={({ id, name, type }) =>
            patchSegment.mutate({
              id,
              name,
              type,
              segment_data: {
                filters: query.filters,
                labels: query.labels
              }
            })
          }
        />
      )}
    </div>
  )
}
