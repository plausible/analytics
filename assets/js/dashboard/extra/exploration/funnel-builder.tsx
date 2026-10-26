import React, { ReactNode, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { InformationCircleIcon } from '@heroicons/react/24/outline'
import { Tooltip } from '../../util/tooltip'
import { useSiteContext } from '../../site-context'
import { useDashboardStateContext } from '../../dashboard-state-context'
import {
  numberShortFormatter,
  rateFormatter
} from '../../util/number-formatter'
import { Button } from '../../components/button'
import {
  FunnelBuildTarget,
  FunnelDraft,
  SavedFunnel
} from '../../funnels-context'
import {
  FunnelType,
  funnelTypeDescriptions,
  funnelTypeLabels
} from '../funnel/metrics'
import {
  fetchFunnelDefinition,
  useCreateFunnel,
  useUpdateFunnel
} from '../funnel/funnel-api'
import { SaveFunnelModal } from '../funnel/funnel-modals'
import { InlineDropdown } from './exploration-column'
import { JourneyColumns } from './journey-columns'
import { JourneyStep } from './journey'
import { DIRECTION } from './constants'
import {
  draftInvalidReason,
  journeyStepToFunnelStep,
  savedStepToJourneyStep
} from './funnel-draft'
import {
  droppedFunnelFilters,
  useFunnelBuilderData
} from './funnel-builder-state'

const FUNNEL_TYPE_OPTIONS = Object.values(FunnelType).map((value) => ({
  value,
  label: funnelTypeLabels[value]
}))

type EditedFunnel = { id: number; name: string }

// Lets the user compose a funnel out of pages, events and goals and save it,
// either as a new funnel, or over a saved one being edited.
export function FunnelBuilder({
  target,
  draft,
  onCancel,
  onSaved
}: {
  target: FunnelBuildTarget
  draft: FunnelDraft | null
  onCancel: () => void
  onSaved: (funnel: SavedFunnel) => void
}): ReactNode {
  const site = useSiteContext()

  const definitionQuery = useQuery({
    queryKey: ['funnel-definition', target],
    enabled: target !== 'new',
    retry: false,
    gcTime: 0,
    queryFn: () => fetchFunnelDefinition(site.domain, target as number)
  })

  if (target === 'new') {
    return (
      <FunnelBuilderView
        initialSteps={draft?.steps ?? []}
        initialFunnelType={draft?.funnelType ?? FunnelType.sequential}
        editedFunnel={null}
        onCancel={onCancel}
        onSaved={onSaved}
      />
    )
  }

  if (definitionQuery.isPending) {
    return (
      <div className="flex-1 flex items-center justify-center pt-4">
        <div className="mx-auto loading">
          <div></div>
        </div>
      </div>
    )
  }

  if (definitionQuery.isError) {
    return (
      <div className="flex-1 flex flex-col items-center justify-center gap-3 pt-4 text-sm text-gray-500 dark:text-gray-400">
        <span>This funnel could not be loaded. Perhaps it was deleted?</span>
        <Button theme="secondary" size="sm" onClick={onCancel}>
          Back to exploring
        </Button>
      </div>
    )
  }

  const definition = definitionQuery.data

  return (
    <FunnelBuilderView
      initialSteps={definition.steps.map(savedStepToJourneyStep)}
      initialFunnelType={definition.funnel_type}
      editedFunnel={{ id: definition.id, name: definition.name }}
      onCancel={onCancel}
      onSaved={onSaved}
    />
  )
}

function FunnelBuilderView({
  initialSteps,
  initialFunnelType,
  editedFunnel,
  onCancel,
  onSaved
}: {
  initialSteps: JourneyStep[]
  initialFunnelType: FunnelType
  editedFunnel: EditedFunnel | null
  onCancel: () => void
  onSaved: (funnel: SavedFunnel) => void
}): ReactNode {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const [minSteps, maxSteps] = site.funnelStepsRange
  const [funnelType, setFunnelType] = useState(initialFunnelType)
  const [saving, setSaving] = useState(false)

  const createFunnel = useCreateFunnel()
  const updateFunnel = useUpdateFunnel()

  const {
    journey,
    activeLoading,
    previewLoading,
    previewError,
    rateLimited,
    candidatesFailed,
    layoutKey,
    selectStep,
    setActiveFilter,
    retry
  } = useFunnelBuilderData({
    site,
    dashboardState,
    initialSteps,
    funnelType,
    maxSteps
  })

  const { steps, funnel } = journey

  const invalidReason = draftInvalidReason(steps, {
    minSteps,
    maxSteps,
    journeyEndEvent: site.explorationJourneyEndEvent
  })

  const lastFunnelStep = funnel.length >= 2 ? funnel[funnel.length - 1] : null

  const mutation = createFunnel.isPending ? createFunnel : updateFunnel
  const requestError = createFunnel.error ?? updateFunnel.error

  function save({ name, asNew }: { name: string; asNew: boolean }) {
    const input = {
      name,
      funnel_type: funnelType,
      steps: steps.map(journeyStepToFunnelStep)
    }

    const onSuccess = (funnel: SavedFunnel) => {
      setSaving(false)
      onSaved(funnel)
    }

    if (editedFunnel && !asNew) {
      updateFunnel.mutate({ id: editedFunnel.id, ...input }, { onSuccess })
    } else {
      createFunnel.mutate(input, { onSuccess })
    }
  }

  function resetRequests() {
    createFunnel.reset()
    updateFunnel.reset()
  }

  return (
    <div
      className="flex-1 flex flex-col gap-4 pt-4"
      data-testid="funnel-builder"
    >
      <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
        <h4
          data-testid="funnel-builder-title"
          className="flex-1 min-w-0 truncate text-base font-semibold dark:text-gray-100"
        >
          {editedFunnel ? `Editing “${editedFunnel.name}”` : 'New funnel'}
        </h4>

        <div className="flex items-center gap-1 text-xs text-gray-500 dark:text-gray-400">
          <InlineDropdown
            value={funnelType}
            options={FUNNEL_TYPE_OPTIONS}
            onChange={setFunnelType}
            testId="funnel-builder-type"
            align="right"
          />
          <Tooltip
            className="flex"
            containerRef={{ current: document.body }}
            info={<span>{funnelTypeDescriptions[funnelType]}</span>}
          >
            <InformationCircleIcon className="size-3.5" />
          </Tooltip>
        </div>

        {lastFunnelStep && (
          <div
            data-testid="funnel-builder-conversion-rate"
            className={`text-xs ${previewLoading ? 'opacity-50' : ''}`}
          >
            <span className="font-semibold text-gray-700 dark:text-gray-200">
              CR: {rateFormatter(lastFunnelStep.conversion_rate)}{' '}
            </span>
            <span className="text-gray-500 dark:text-gray-400">
              ({numberShortFormatter(lastFunnelStep.visitors)})
            </span>
          </div>
        )}

        <div className="flex items-center gap-2">
          <Button
            theme="secondary"
            size="sm"
            onClick={onCancel}
            data-testid="funnel-builder-cancel"
          >
            Cancel
          </Button>
          {invalidReason !== null ? (
            <Tooltip info={invalidReason}>
              <Button size="sm" disabled data-testid="funnel-builder-save">
                Save funnel
              </Button>
            </Tooltip>
          ) : (
            <Button
              size="sm"
              onClick={() => setSaving(true)}
              data-testid="funnel-builder-save"
            >
              Save funnel
            </Button>
          )}
        </div>
      </div>

      {droppedFunnelFilters(dashboardState) && (
        <p className="text-xs text-gray-500 dark:text-gray-400">
          Page and goal filters are not applied while building a funnel.
        </p>
      )}

      {previewError && (
        <p
          data-testid="funnel-builder-error"
          className="text-xs text-red-600 dark:text-red-400"
        >
          {previewError}
        </p>
      )}

      <JourneyColumns
        journey={journey}
        direction={DIRECTION.FORWARD}
        columnHeader={(index) => `Step ${index + 1}`}
        initialLoading={false}
        activeLoading={activeLoading}
        rateLimited={rateLimited}
        failed={candidatesFailed}
        pageTypingAllowed
        suggestionCountsOnFirstStepOnly
        maxSteps={maxSteps}
        maxDepthMessage={`A funnel can have at most ${maxSteps} steps.`}
        layoutKey={layoutKey}
        onSelect={selectStep}
        onFilterChange={setActiveFilter}
        onRetry={retry}
      />

      {saving && (
        <SaveFunnelModal
          initialName={editedFunnel?.name ?? ''}
          editing={editedFunnel !== null}
          onClose={() => {
            resetRequests()
            setSaving(false)
          }}
          onSave={save}
          pending={mutation.isPending}
          error={requestError}
          resetError={resetRequests}
        />
      )}
    </div>
  )
}
