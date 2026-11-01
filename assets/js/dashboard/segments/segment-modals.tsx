import React, { ReactNode, useState } from 'react'
import {
  ModalLayout,
  ModalFooter,
  SaveButton
} from '../components/modal-layout'
import {
  SavedSegment,
  SEGMENT_TYPE_LABELS,
  SegmentType
} from '../filtering/segments'
import { MutationStatus, useQuery } from '@tanstack/react-query'
import { ApiError, get } from '../api'
import { ErrorPanel } from '../components/error-panel'
import { Role, UserContextValue } from '../user-context'
import { useSiteContext } from '../site-context'
import { Button } from '../components/button'
import {
  Checkbox,
  getOptionDisabledMessage,
  LabeledTextInput,
  OptionDisabledMessageType,
  TypeSelector
} from '../components/form-elements'
import { UpgradePill } from '../components/pill'

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
}

export const CreateSegmentModal = ({
  segment,
  onClose,
  onSave,
  siteSegmentsAvailable: siteSegmentsAvailable,
  user,
  suggestedName,
  error,
  reset,
  status
}: SegmentModalProps &
  ApiRequestProps & {
    segment?: SavedSegment
    suggestedName: string
    onSave: (input: Pick<SavedSegment, 'name' | 'type'>) => void
  }) => {
  const defaultName = segment?.name
    ? `Copy of ${segment.name}`.slice(0, 255)
    : suggestedName
  const [name, setName] = useState(defaultName)
  const defaultType =
    segment?.type === SegmentType.site &&
    siteSegmentsAvailable &&
    hasSiteSegmentPermission(user)
      ? SegmentType.site
      : SegmentType.personal

  const [type, setType] = useState<SegmentType>(defaultType)

  const siteOptionDisabledMessage = getSiteSegmentDisabledMessage({
    siteSegmentsAvailable,
    user
  })

  const disabledMessage =
    type === SegmentType.site ? siteOptionDisabledMessage : null

  return (
    <ModalLayout title="Create segment" onClose={onClose}>
      <LabeledTextInput
        {...nameInputProps}
        focusOnMount
        value={name}
        onChange={setName}
        placeholder={suggestedName}
      />
      <SegmentTypeSelector
        type={type}
        setType={setType}
        siteOptionDisabledMessage={siteOptionDisabledMessage}
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
              : suggestedName
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

function getDeleteNotice(segment: SavedSegment, links: string[]) {
  if (links.length === 1) {
    return 'This segment is used by a shared link. To delete the segment, this link must also be deleted:'
  }
  if (links.length > 1) {
    return `This segment is used by ${links.length} shared links. To delete the segment, these links must also be deleted:`
  }
  if (segment.type === SegmentType.site) {
    return 'This site segment will be removed for everyone with access to this dashboard. Are you sure?'
  }
  return 'Are you sure?'
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
  segment: SavedSegment
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

  const links = linksQuery.data ?? []
  const deleteDisabled =
    status === 'pending' ||
    linksQuery.status !== 'success' ||
    (!!links.length && !confirmed)

  return (
    <ModalLayout
      title={`Delete ${SEGMENT_TYPE_LABELS[segment.type].toLowerCase()}`}
      onClose={onClose}
    >
      <p className="text-sm dark:text-gray-100">
        {`You’re about to delete `}
        <span className="break-all font-semibold">{`“${segment.name}”`}</span>
        {'. '}
        {linksQuery.status === 'success' && getDeleteNotice(segment, links)}
      </p>
      {linksQuery.status === 'pending' && (
        <div className="loading sm">
          <div />
        </div>
      )}
      {linksQuery.status === 'error' && (
        <ErrorPanel
          errorMessage="Error loading related shared links"
          onRetry={linksQuery.refetch}
        />
      )}
      {!!links.length && (
        <>
          <div className="flex flex-col items-start gap-y-1 text-sm">
            {links.map((name, index) => (
              <a
                key={index}
                href={`/${encodeURIComponent(site.domain)}/settings/visibility`}
                className="break-words text-indigo-600 hover:text-indigo-700 dark:text-indigo-500 dark:hover:text-indigo-400"
              >
                {name}
              </a>
            ))}
          </div>
          <Checkbox
            id="confirm"
            checked={confirmed}
            onChange={(e) => setConfirmed(e.currentTarget.checked)}
          >
            {links.length === 1
              ? 'Also delete this shared link'
              : `Also delete these ${links.length} shared links`}
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
          {links.length === 0
            ? 'Delete'
            : links.length === 1
              ? 'Delete segment and link'
              : 'Delete segment and links'}
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
  siteOptionDisabledMessage
}: {
  type: SegmentType
  setType: (type: SegmentType) => void
  siteOptionDisabledMessage: OptionDisabledMessageType | null
}) => (
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
        description: 'Visible to others on the site',
        disabled: siteOptionDisabledMessage !== null,
        pill:
          siteOptionDisabledMessage === 'upgrade-subscription-yourself' ||
          siteOptionDisabledMessage === 'upgrade-subscription-reach-out' ? (
            <UpgradePill
              plan="Upgrade needed"
              linked={
                siteOptionDisabledMessage === 'upgrade-subscription-yourself'
              }
            />
          ) : null,
        tooltipContent:
          siteOptionDisabledMessage !== null ? (
            <SegmentTypeDisabledMessage
              messageType={siteOptionDisabledMessage}
            />
          ) : null
      }
    ]}
    value={type}
    onChange={setType}
  />
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
      return 'Upgrade your plan to share segments with others.'
    }
    case 'upgrade-subscription-reach-out': {
      return 'Ask a team owner to upgrade your plan to share segments with others.'
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
    namePlaceholder: string
    onSave: (input: Pick<SavedSegment, 'id' | 'name' | 'type'>) => void
    segment: SavedSegment
  }) => {
  const [name, setName] = useState(segment.name)
  const [type, setType] = useState<SegmentType>(segment.type)

  const siteOptionDisabledMessage = getSiteSegmentDisabledMessage({
    siteSegmentsAvailable,
    user
  })

  const disabledMessage =
    type === SegmentType.site ? siteOptionDisabledMessage : null

  return (
    <ModalLayout title="Update segment" onClose={onClose}>
      <LabeledTextInput
        {...nameInputProps}
        focusOnMount
        value={name}
        onChange={setName}
        placeholder={namePlaceholder}
      />
      <SegmentTypeSelector
        type={type}
        setType={setType}
        siteOptionDisabledMessage={siteOptionDisabledMessage}
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

const hasSiteSegmentPermission = (user: UserContextValue) => {
  return [Role.admin, Role.owner, Role.editor, 'super_admin'].includes(
    user.role
  )
}
