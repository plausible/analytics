/** @format */

import React from 'react'
import { useSegmentExpandedContext } from './segment-expanded-context'
import {
  CreateSegmentModal,
  DeleteSegmentModal,
  UpdateSegmentModal
} from './segment-modals'
import {
  getSearchToApplySingleSegmentFilter,
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
import { mutation } from '../api'

export const RoutelessSegmentModals = () => {
  const navigate = useAppNavigate()
  const queryClient = useQueryClient()
  const site = useSiteContext()
  const { query } = useQueryContext()
  const user = useUserContext()
  const { expandedSegment, modal, setModal } = useSegmentExpandedContext()

  const patchSegment = useMutation({
    mutationFn: async ({
      id,
      name,
      type,
      segment_data
    }: Pick<SavedSegment, 'id'> &
      Partial<Pick<SavedSegment, 'name' | 'type'>> & {
        segment_data?: SegmentData
      }) => {
      const response: SavedSegment & { segment_data: SegmentData } =
        await mutation(
          `/api/${encodeURIComponent(site.domain)}/segments/${id}`,
          {
            method: 'PATCH',
            body: {
              name,
              type,
              ...(segment_data && {
                segment_data: {
                  filters: remapToApiFilters(segment_data.filters),
                  labels: cleanLabels(segment_data.filters, segment_data.labels)
                }
              })
            }
          }
        )

      return {
        ...response,
        segment_data: parseApiSegmentData(response.segment_data)
      }
    },
    onSuccess: async (segment) => {
      queryClient.invalidateQueries({ queryKey: ['segments'] })
      navigate({
        search: getSearchToApplySingleSegmentFilter(segment),
        state: {
          expandedSegment: null
        }
      })
      setModal(null)
    }
  })

  const createSegment = useMutation({
    mutationFn: async ({
      name,
      type,
      segment_data
    }: {
      name: string
      type: 'personal' | 'site'
      segment_data: SegmentData
    }) => {
      const response: SavedSegment & { segment_data: SegmentData } =
        await mutation(`/api/${encodeURIComponent(site.domain)}/segments`, {
          method: 'POST',
          body: {
            name,
            type,
            segment_data: {
              filters: remapToApiFilters(segment_data.filters),
              labels: cleanLabels(segment_data.filters, segment_data.labels)
            }
          }
        })
      return {
        ...response,
        segment_data: parseApiSegmentData(response.segment_data)
      }
    },
    onSuccess: async (segment) => {
      queryClient.invalidateQueries({ queryKey: ['segments'] })
      navigate({
        search: getSearchToApplySingleSegmentFilter(segment),
        state: {
          expandedSegment: null
        }
      })
      setModal(null)
    }
  })

  const deleteSegment = useMutation({
    mutationFn: async (data: Pick<SavedSegment, 'id'>) => {
      const response: SavedSegment & { segment_data: SegmentData } =
        await mutation(
          `/api/${encodeURIComponent(site.domain)}/segments/${data.id}`,
          {
            method: 'DELETE'
          }
        )
      return {
        ...response,
        segment_data: parseApiSegmentData(response.segment_data)
      }
    },
    onSuccess: (_segment): void => {
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
          status={patchSegment.status}
          error={patchSegment.error}
          reset={patchSegment.reset}
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
          status={createSegment.status}
          error={createSegment.error}
          reset={createSegment.reset}
        />
      )}
      {modal === 'delete' && expandedSegment && (
        <DeleteSegmentModal
          segment={expandedSegment}
          onClose={() => setModal(null)}
          onSave={({ id }) => deleteSegment.mutate({ id })}
          status={deleteSegment.status}
          error={deleteSegment.error}
          reset={deleteSegment.reset}
        />
      )}
    </>
  )
}
