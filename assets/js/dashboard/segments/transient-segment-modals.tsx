/** @format */

import React from 'react'
import { useSegmentExpandedContext } from './segment-expanded-context'
import {
  CreateSegmentModal,
  DeleteSegmentModal,
  UpdateSegmentModal
} from './segment-modals'
import {
  formatSegmentIdAsLabelKey,
  getSegmentNamePlaceholder,
  parseApiSegmentData,
  SavedSegment,
  SegmentData
} from '../filtering/segments'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useSiteContext } from '../site-context'
import { cleanLabels, remapToApiFilters } from '../util/filters'
import { useAppNavigate } from '../navigation/use-app-navigate'
import { useQueryContext } from '../query-context'
import { Role, useUserContext } from '../user-context'

export const TransientSegmentModals = (_p: { closeList: () => void }) => {
  const navigate = useAppNavigate()
  const queryClient = useQueryClient()
  const site = useSiteContext()
  const { expandedSegment, modal, setModal } = useSegmentExpandedContext()
  const { query } = useQueryContext()
  const user = useUserContext()

  const patchSegment = useMutation({
    mutationFn: ({
      id,
      name,
      type,
      segment_data
    }: Pick<SavedSegment, 'id'> &
      Partial<Pick<SavedSegment, 'name' | 'type'>> & {
        segment_data?: SegmentData
      }) => {
      return fetch(`/api/${encodeURIComponent(site.domain)}/segments/${id}`, {
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
      })
        .then((res) => res.json())
        .then((d) => ({
          ...d,
          segment_data: parseApiSegmentData(d.segment_data)
        }))
    },
    onSuccess: async (d) => {
      queryClient.invalidateQueries({ queryKey: ['segments'] })
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
        state: {
          expandedSegment: null
        }
        // replace: true
      })
      setModal(null)
    }
  })

  const createSegment = useMutation({
    mutationFn: ({
      name,
      type,
      segment_data
    }: {
      name: string
      type: 'personal' | 'site'
      segment_data: SegmentData
    }) => {
      return fetch(`/api/${encodeURIComponent(site.domain)}/segments`, {
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
      })
        .then((res) => res.json())
        .then((d) => ({
          ...d,
          segment_data: parseApiSegmentData(d.segment_data)
        }))
    },
    onSuccess: async (d) => {
      navigate({
        search: (search) => {
          queryClient.invalidateQueries({ queryKey: ['segments'] })
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
        state: {
          expandedSegment: null
        }
        // replace: true
      })
      setModal(null)
    }
  })

  const deleteSegment = useMutation({
    mutationFn: (data: Pick<SavedSegment, 'id'>) => {
      return fetch(
        `/api/${encodeURIComponent(site.domain)}/segments/${data.id}`,
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
      navigate({
        search: (s) => {
          return {
            ...s,
            filters: null,
            labels: null
          }
        },
        state: {
          expandedSegment: null
        }
        // replace: true
      })
      setModal(null)
    }
  })

  if (!user.loggedIn || !site.flags.saved_segments) {
    return null
  }

  const userCanSelectSiteSegment = [
    Role.admin,
    Role.owner,
    Role.editor,
    'super_admin'
  ].includes(user.role)

  return (
    <>
      {modal === 'update' && expandedSegment && (
        <UpdateSegmentModal
          userCanSelectSiteSegment={userCanSelectSiteSegment}
          siteSegmentsAvailable={site.siteSegmentsAvailable}
          segment={expandedSegment}
          namePlaceholder={getSegmentNamePlaceholder(query)}
          onClose={() => setModal(null)}
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
      {modal === 'create' && (
        <CreateSegmentModal
          userCanSelectSiteSegment={userCanSelectSiteSegment}
          siteSegmentsAvailable={site.siteSegmentsAvailable}
          namePlaceholder={getSegmentNamePlaceholder(query)}
          segment={expandedSegment ?? undefined}
          onClose={() => setModal(null)}
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
      {modal === 'delete' && expandedSegment && (
        <DeleteSegmentModal
          segment={expandedSegment}
          onClose={() => setModal(null)}
          onSave={({ id }) => deleteSegment.mutate({ id })}
        />
      )}
    </>
  )
}
