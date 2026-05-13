import React, { ReactNode, useState } from 'react'
import {
  ModalLayout,
  ModalFooter,
  SaveButton
} from '../components/modal-layout'
import {
  canRemoveFilter,
  getSearchToRemoveSegmentFilter,
  canExpandSegment,
  SavedSegment,
  SEGMENT_TYPE_LABELS,
  SegmentData,
  SegmentType
} from '../filtering/segments'
import {
  AppNavigationLink,
  useAppNavigate
} from '../navigation/use-app-navigate'
import { plainFilterText, styledFilterText } from '../util/filter-text'
import { rootRoute } from '../router'
import { FilterPillsList } from '../nav-menu/filter-pills-list'
import classNames from 'classnames'
import { SegmentAuthorship } from './segment-authorship'
import { MutationStatus, useQuery } from '@tanstack/react-query'
import { ApiError, get } from '../api'
import { ErrorPanel } from '../components/error-panel'
import { useSegmentsContext } from '../filtering/segments-context'
import { Role, UserContextValue, useUserContext } from '../user-context'
import { useSiteContext } from '../site-context'
import { Button, buttonClassName } from '../components/button'
import {
  Checkbox,
  getOptionDisabledMessage,
  LabeledTextInput,
  OptionDisabledMessageType,
  TypeDisabledMessage,
  TypeSelector
} from '../components/form-elements'
import { Placeholder } from '../components/placeholder'

const inModalSectionLabelClassName = 'text-sm font-semibold dark:text-gray-100'

const nameInputProps = { id: 'name', label: 'Segment name' }

interface ApiRequestProps {
  status: MutationStatus
  error?: unknown
  reset: () => void
}

interface SegmentModalProps {
  user: UserContextValue
  siteSegmentsAvailable: boolean
  onClose: () => void
  namePlaceholder: string
}

export const CreateSegmentModal = ({
  segment,
  onClose,
  onSave,
  siteSegmentsAvailable: siteSegmentsAvailable,
  user,
  namePlaceholder,
  error,
  reset,
  status
}: SegmentModalProps &
  ApiRequestProps & {
    segment?: SavedSegment
    onSave: (input: Pick<SavedSegment, 'name' | 'type'>) => void
  }) => {
  const defaultName = segment?.name
    ? `Copy of ${segment.name}`.slice(0, 255)
    : ''
  const [name, setName] = useState(defaultName)
  const defaultType =
    segment?.type === SegmentType.site &&
    siteSegmentsAvailable &&
    hasSiteSegmentPermission(user)
      ? SegmentType.site
      : SegmentType.personal

  const [type, setType] = useState<SegmentType>(defaultType)

  const disabledMessage =
    type === SegmentType.site
      ? getSiteSegmentDisabledMessage({
          siteSegmentsAvailable,
          user
        })
      : null

  return (
    <ModalLayout title="Create segment" onClose={onClose}>
      <LabeledTextInput
        {...nameInputProps}
        value={name}
        onChange={setName}
        placeholder={namePlaceholder}
      />
      <SegmentTypeSelector
        type={type}
        setType={setType}
        optionDisabledMessage={disabledMessage}
      />
      <ModalFooter>
        <Button theme="secondary" size="sm" onClick={onClose}>
          Cancel
        </Button>
        <SaveButton
          disabled={status === 'pending' || disabledMessage !== null}
          onSave={() => {
            const trimmedName = name.trim()
            const saveableName = trimmedName.length
              ? trimmedName
              : namePlaceholder
            onSave({ name: saveableName, type })
          }}
        />
      </ModalFooter>
      {error !== null && (
        <ErrorPanel
          className="mt-4"
          errorMessage={
            error instanceof ApiError
              ? error.message
              : 'Something went wrong creating segment'
          }
          onClose={reset}
        />
      )}
    </ModalLayout>
  )
}

function getLinksDeleteNotice(links: string[]) {
  return links.length === 1
    ? 'This segment is used in a shared link. To delete it, you also need to delete the shared link.'
    : `This segment is used in ${links.length} shared links. To delete it, you also need to delete the shared links.`
}

export const DeleteSegmentModal = ({
  onClose,
  onSave,
  segment,
  status,
  error,
  reset
}: {
  onClose: () => void
  onSave: (input: Pick<SavedSegment, 'id'>) => void
  segment: SavedSegment & { segment_data?: SegmentData }
} & ApiRequestProps) => {
  const site = useSiteContext()
  const [confirmed, setConfirmed] = useState(false)

  const linksQuery = useQuery({
    queryKey: [segment.id],
    queryFn: async () => {
      const response: string[] = await get(
        `/api/${encodeURIComponent(site.domain)}/segments/${segment.id}/shared-links`
      )
      return response
    }
  })

  const deleteDisabled =
    status === 'pending' ||
    linksQuery.status !== 'success' ||
    (!!linksQuery.data?.length && !confirmed)

  return (
    <ModalLayout
      title={`Delete ${SEGMENT_TYPE_LABELS[segment.type].toLowerCase()}`}
      onClose={onClose}
    >
      <div className="flex flex-col gap-y-2">
        <p className="text-sm dark:text-gray-100">
          {`You're about to delete `}
          <span className="break-all font-semibold">{`"${segment.name}"`}</span>
          {`. Are you sure?`}
        </p>
        {linksQuery.status === 'pending' && (
          <div className="loading sm">
            <div />
          </div>
        )}
        {linksQuery.status === 'success' && !!linksQuery.data?.length && (
          <ErrorPanel
            errorMessage={
              <span className="break-normal">
                {getLinksDeleteNotice(linksQuery.data)}
              </span>
            }
          />
        )}
        {linksQuery.status === 'error' && (
          <ErrorPanel
            errorMessage="Error loading related shared links"
            onRetry={linksQuery.refetch}
          />
        )}
      </div>
      {!!segment.segment_data && (
        <FiltersInSegment
          segment_data={segment.segment_data}
          className={linksQuery.data?.length ? undefined : 'mb-4'}
        />
      )}
      {!!linksQuery.data?.length && (
        <>
          <RelatedSharedLinks sharedLinks={linksQuery.data} />
          <Checkbox
            id="confirm"
            checked={confirmed}
            onChange={(e) => setConfirmed(e.currentTarget.checked)}
          >
            Yes, delete the associated shared links
          </Checkbox>
        </>
      )}
      <ModalFooter>
        <Button theme="secondary" size="sm" onClick={onClose}>
          Cancel
        </Button>
        <Button
          theme="danger"
          size="sm"
          disabled={deleteDisabled}
          onClick={
            deleteDisabled
              ? () => {}
              : () => {
                  onSave({ id: segment.id })
                }
          }
        >
          Delete
        </Button>
      </ModalFooter>
      {error !== null && (
        <ErrorPanel
          className="mt-4"
          errorMessage={
            error instanceof ApiError
              ? error.message
              : 'Something went wrong deleting segment'
          }
          onClose={reset}
        />
      )}
    </ModalLayout>
  )
}

const RelatedSharedLinks = ({ sharedLinks }: { sharedLinks: string[] }) => {
  return (
    <div className="flex flex-col gap-y-2">
      <p className={inModalSectionLabelClassName}>Shared links</p>
      <FilterPillsList
        className="flex-wrap"
        direction="horizontal"
        pills={sharedLinks.map((name) => ({
          className: 'dark:!shadow-gray-950/60',
          plainText: name,
          children: name,
          interactive: false
        }))}
      />
    </div>
  )
}

const getSiteSegmentDisabledMessage = ({
  siteSegmentsAvailable,
  user
}: {
  siteSegmentsAvailable: boolean
  user: UserContextValue
}) =>
  getOptionDisabledMessage({
    optionAvailable: siteSegmentsAvailable,
    userHasOptionPermissions: hasSiteSegmentPermission(user),
    userCanUpgradeSubscription: user.role === Role.owner
  })

const SegmentTypeSelector = ({
  type,
  setType,
  optionDisabledMessage
}: {
  type: SegmentType
  setType: (type: SegmentType) => void
  optionDisabledMessage: OptionDisabledMessageType | null
}) => (
  <>
    <TypeSelector<SegmentType>
      idPrefix="segment-type"
      options={[
        {
          type: SegmentType.personal,
          name: SEGMENT_TYPE_LABELS[SegmentType.personal],
          description: 'Visible only to you'
        },
        {
          type: SegmentType.site,
          name: SEGMENT_TYPE_LABELS[SegmentType.site],
          description: 'Visible to others on the site'
        }
      ]}
      value={type}
      onChange={setType}
    />
    {optionDisabledMessage !== null && (
      <TypeDisabledMessage
        message={
          <SegmentTypeDisabledMessage messageType={optionDisabledMessage} />
        }
      />
    )}
  </>
)

const SegmentTypeDisabledMessage = ({
  messageType
}: {
  messageType: OptionDisabledMessageType
}): Exclude<ReactNode, undefined> => {
  switch (messageType) {
    case 'no-permissions': {
      return "You don't have enough permissions to change segment to this type"
    }
    case 'upgrade-subscription-yourself': {
      return (
        <>
          To use this segment type,{' '}
          <a href="/billing/choose-plan" className="underline">
            please upgrade your subscription
          </a>
        </>
      )
    }
    case 'upgrade-subscription-reach-out': {
      return (
        <>
          To use this segment type, please reach out to a team owner to upgrade
          their subscription
        </>
      )
    }
  }
}

export const UpdateSegmentModal = ({
  onClose,
  onSave,
  segment,
  siteSegmentsAvailable,
  user,
  namePlaceholder,
  status,
  error,
  reset
}: SegmentModalProps &
  ApiRequestProps & {
    onSave: (input: Pick<SavedSegment, 'id' | 'name' | 'type'>) => void
    segment: SavedSegment
  }) => {
  const [name, setName] = useState(segment.name)
  const [type, setType] = useState<SegmentType>(segment.type)

  const disabledMessage =
    type === SegmentType.site
      ? getSiteSegmentDisabledMessage({
          siteSegmentsAvailable,
          user
        })
      : null

  return (
    <ModalLayout title="Update segment" onClose={onClose}>
      <LabeledTextInput
        {...nameInputProps}
        value={name}
        onChange={setName}
        placeholder={namePlaceholder}
      />
      <SegmentTypeSelector
        type={type}
        setType={setType}
        optionDisabledMessage={disabledMessage}
      />
      <ModalFooter>
        <Button theme="secondary" size="sm" onClick={onClose}>
          Cancel
        </Button>
        <SaveButton
          disabled={status === 'pending' || disabledMessage !== null}
          onSave={() => {
            const trimmedName = name.trim()
            const saveableName = trimmedName.length
              ? trimmedName
              : namePlaceholder
            onSave({ id: segment.id, name: saveableName, type })
          }}
        />
      </ModalFooter>
      {error !== null && (
        <ErrorPanel
          className="mt-4"
          errorMessage={
            error instanceof ApiError
              ? error.message
              : 'Something went wrong updating segment'
          }
          onClose={reset}
        />
      )}
    </ModalLayout>
  )
}

const FiltersInSegment = ({
  segment_data,
  className
}: {
  segment_data: SegmentData
  className?: string
}) => {
  return (
    <div className={classNames('flex flex-col gap-y-2', className)}>
      <p className={inModalSectionLabelClassName}>Filters in segment</p>
      <FilterPillsList
        className="flex-wrap"
        direction="horizontal"
        pills={segment_data.filters.map((filter) => ({
          className: 'dark:!shadow-gray-950/60',
          plainText: plainFilterText({ labels: segment_data.labels }, filter),
          children: styledFilterText({ labels: segment_data.labels }, filter),
          interactive: false
        }))}
      />
    </div>
  )
}

const hasSiteSegmentPermission = (user: UserContextValue) => {
  return [Role.admin, Role.owner, Role.editor, 'super_admin'].includes(
    user.role
  )
}

export const SegmentModal = ({ id }: { id: SavedSegment['id'] }) => {
  const user = useUserContext()
  const { segments, limitedToSegment } = useSegmentsContext()
  const navigate = useAppNavigate()

  const segment = segments.find((s) => String(s.id) === String(id))

  let error: ApiError | null = null

  if (!segment) {
    error = new ApiError(
      `Segment not found with with ID "${id}"`,
      {
        error: `Segment not found with with ID "${id}"`
      },
      404
    )
  }

  const data = !error ? segment : null

  const showClearButton = canRemoveFilter(
    ['is', 'segment', [id]],
    limitedToSegment
  )

  const onClose = () => navigate({ path: rootRoute.path, search: (s) => s })

  return (
    <ModalLayout title="Segment details" onClose={onClose}>
      <div className="flex flex-col gap-y-6 dark:text-gray-100">
        <div className="text-sm flex flex-col gap-y-0.5">
          <h2 className="font-semibold break-all">
            <Placeholder placeholder="Segment name">
              {data?.name ?? false}
            </Placeholder>
          </h2>
          <div className="text-gray-500 dark:text-gray-400">
            <Placeholder placeholder="Segment type">
              {data?.segment_data ? SEGMENT_TYPE_LABELS[data.type] : false}
            </Placeholder>
            {!!data?.segment_data && (
              <>
                {' • '}
                <SegmentAuthorship
                  segment={data}
                  showOnlyPublicData={
                    !user.loggedIn || user.role === Role.public
                  }
                />
              </>
            )}
          </div>
        </div>
        {!!data?.segment_data && (
          <>
            <FiltersInSegment
              segment_data={data.segment_data}
              className="mb-4"
            />

            <ModalFooter>
              {showClearButton && (
                <Button
                  theme="secondary"
                  size="sm"
                  onClick={() =>
                    navigate({
                      path: rootRoute.path,
                      search: getSearchToRemoveSegmentFilter()
                    })
                  }
                >
                  Remove filter
                </Button>
              )}

              {canExpandSegment({ segment: data, user }) && (
                <AppNavigationLink
                  className={buttonClassName({ size: 'sm' })}
                  path={rootRoute.path}
                  search={(s) => ({
                    ...s,
                    filters: data.segment_data.filters,
                    labels: data.segment_data.labels
                  })}
                  state={{
                    expandedSegment: data
                  }}
                >
                  Edit segment
                </AppNavigationLink>
              )}
            </ModalFooter>
          </>
        )}
        {error !== null && (
          <ErrorPanel
            className="mt-4"
            errorMessage={
              error instanceof ApiError
                ? error.message
                : 'Something went wrong loading segment'
            }
            onRetry={() => window.location.reload()}
          />
        )}
      </div>
    </ModalLayout>
  )
}
