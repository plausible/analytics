import React from 'react'
import {
  CreateSegmentModal,
  DeleteSegmentModal,
  UpdateSegmentModal
} from './segment-modals'
import { getSegmentNamePlaceholder } from '../filtering/segments'
import { useSiteContext } from '../site-context'
import { useDashboardStateContext } from '../dashboard-state-context'
import { useUserContext } from '../user-context'
import { useRoutelessModalsContext } from '../navigation/routeless-modals-context'
import {
  useCreateSegment,
  useDeleteSegment,
  usePatchSegment
} from './use-segment-mutations'

export type RoutelessSegmentModal =
  | { type: 'create-segment' }
  | { type: 'update-segment' }
  | { type: 'delete-segment' }

export const RoutelessSegmentModals = () => {
  const site = useSiteContext()
  const { modal, setModal } = useRoutelessModalsContext()
  const { dashboardState, expandedSegment } = useDashboardStateContext()
  const user = useUserContext()
  const patchSegment = usePatchSegment()
  const createSegment = useCreateSegment()
  const deleteSegment = useDeleteSegment()

  if (!user.loggedIn) {
    return null
  }

  return (
    <>
      {modal?.type === 'update-segment' && expandedSegment && (
        <UpdateSegmentModal
          user={user}
          siteSegmentsAvailable={site.siteSegmentsAvailable}
          segment={expandedSegment}
          namePlaceholder={getSegmentNamePlaceholder(dashboardState)}
          onClose={() => {
            setModal(null)
            patchSegment.reset()
          }}
          onSave={({ id, name, type }) =>
            patchSegment.mutate({
              id,
              name,
              type,
              segment_data: {
                filters: dashboardState.filters,
                labels: dashboardState.labels
              }
            })
          }
          status={patchSegment.status}
          error={patchSegment.error}
          reset={patchSegment.reset}
        />
      )}
      {modal?.type === 'create-segment' && (
        <CreateSegmentModal
          user={user}
          siteSegmentsAvailable={site.siteSegmentsAvailable}
          suggestedName={getSegmentNamePlaceholder(dashboardState)}
          segment={expandedSegment ?? undefined}
          onClose={() => {
            setModal(null)
            createSegment.reset()
          }}
          onSave={({ name, type }) =>
            createSegment.mutate({
              name,
              type,
              segment_data: {
                filters: dashboardState.filters,
                labels: dashboardState.labels
              }
            })
          }
          status={createSegment.status}
          error={createSegment.error}
          reset={createSegment.reset}
        />
      )}
      {modal?.type === 'delete-segment' && expandedSegment && (
        <DeleteSegmentModal
          segment={expandedSegment}
          onClose={() => {
            setModal(null)
            deleteSegment.reset()
          }}
          onSave={({ id }) => deleteSegment.mutate({ id })}
          status={deleteSegment.status}
          error={deleteSegment.error}
          reset={deleteSegment.reset}
        />
      )}
    </>
  )
}
