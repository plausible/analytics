import React, { ReactNode, useState } from 'react'
import {
  Annotation,
  ANNOTATION_TYPE_LABELS,
  AnnotationGranularity,
  AnnotationPayload,
  AnnotationType,
  canEditAnnotation,
  NOTE_MAX_LENGTH
} from './annotations'
import { MutationStatus } from '@tanstack/react-query'
import { ApiError } from '../api'
import { ErrorPanel } from '../components/error-panel'
import {
  ModalLayout,
  ModalFooter,
  SaveButton
} from '../components/modal-layout'
import {
  LabeledTextarea,
  TypeSelector,
  getOptionDisabledMessage,
  isOverMaxLength,
  OptionDisabledMessageType
} from '../components/form-elements'
import { Button } from '../components/button'
import { UpgradePill } from '../components/pill'
import { Role, UserContextValue } from '../user-context'
import {
  formatDay,
  formatTime,
  is12HourClock,
  parseUTCDate
} from '../util/date'

const formatAnnotationDatetime = (
  datetime: string,
  granularity: AnnotationGranularity
): string => {
  const date = parseUTCDate(datetime)
  if (granularity === AnnotationGranularity.minute) {
    const time = formatTime(date, {
      use12HourClock: is12HourClock(),
      includeMinutes: true
    })
    return `${formatDay(date)} at ${time}`
  }
  return formatDay(date)
}

interface ApiRequestProps {
  status: MutationStatus
  error?: unknown
  reset: () => void
}

interface AnnotationModalProps {
  user: UserContextValue
  siteAnnotationsAvailable: boolean
  onClose: () => void
  notePlaceholder: string
}

export const CreateAnnotationModal = ({
  onClose,
  onSave,
  user,
  siteAnnotationsAvailable,
  notePlaceholder,
  initialDatetime,
  initialGranularity,
  initialType,
  error,
  reset,
  status
}: AnnotationModalProps &
  ApiRequestProps & {
    initialDatetime: AnnotationPayload['datetime']
    initialGranularity: AnnotationPayload['granularity']
    initialType: AnnotationPayload['type']
  } & {
    onSave: (input: AnnotationPayload) => void
  }) => {
  const [note, setNote] = useState('')
  const [type, setType] = useState(initialType)
  const trimmedNote = note.trim()
  const granularity = initialGranularity
  const datetime = initialDatetime

  const siteOptionDisabledMessage = getAnnotationTypeDisabledMessage({
    siteAnnotationsAvailable,
    user
  })

  const disabledMessage =
    type === AnnotationType.site ? siteOptionDisabledMessage : null

  return (
    <ModalLayout
      title={`Add note for ${formatAnnotationDatetime(datetime, granularity)}`}
      onClose={onClose}
    >
      <LabeledTextarea
        label="Note"
        id="note"
        value={note}
        onChange={setNote}
        placeholder={notePlaceholder}
        maxLength={NOTE_MAX_LENGTH}
      />
      <AnnotationTypeSelector
        value={type}
        onChange={setType}
        siteOptionDisabledMessage={siteOptionDisabledMessage}
      />
      <ModalFooter>
        <Button theme="secondary" size="sm" onClick={onClose}>
          Cancel
        </Button>
        <SaveButton
          disabled={isSaveButtonDisabled({
            requestStatus: status,
            disabledMessage,
            trimmedNote
          })}
          onSave={() =>
            onSave({
              note: trimmedNote,
              type,
              datetime,
              granularity
            })
          }
        />
      </ModalFooter>
      {error !== null && (
        <ErrorPanel
          className="mt-4"
          errorMessage={
            error instanceof ApiError
              ? error.message
              : 'Something went wrong adding the note'
          }
          onClose={reset}
        />
      )}
    </ModalLayout>
  )
}

const AnnotationTypeSelector = ({
  value,
  onChange,
  siteOptionDisabledMessage
}: {
  value: AnnotationType
  onChange: (value: AnnotationType) => void
  siteOptionDisabledMessage: OptionDisabledMessageType | null
}) => (
  <TypeSelector<AnnotationType>
    idPrefix="annotation-type"
    value={value}
    onChange={onChange}
    options={[
      {
        type: AnnotationType.personal,
        name: ANNOTATION_TYPE_LABELS[AnnotationType.personal],
        description: 'Visible only to you'
      },
      {
        type: AnnotationType.site,
        name: ANNOTATION_TYPE_LABELS[AnnotationType.site],
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
            <AnnotationTypeDisabledMessage
              messageType={siteOptionDisabledMessage}
            />
          ) : null
      }
    ]}
  />
)

const AnnotationTypeDisabledMessage = ({
  messageType
}: {
  messageType: OptionDisabledMessageType
}): Exclude<ReactNode, undefined> => {
  switch (messageType) {
    case 'no-permissions':
      return "You don't have enough permissions to change note to this type"
    case 'upgrade-subscription-yourself':
      return 'Upgrade your plan to make notes visible to others.'
    case 'upgrade-subscription-reach-out':
      return 'Ask a team owner to upgrade your plan to make notes visible to others.'
  }
}

const getAnnotationTypeDisabledMessage = ({
  siteAnnotationsAvailable,
  user
}: {
  siteAnnotationsAvailable: boolean
  user: UserContextValue
}): OptionDisabledMessageType | null =>
  getOptionDisabledMessage({
    optionAvailable: siteAnnotationsAvailable,
    userHasOptionPermissions: canEditAnnotation({
      type: AnnotationType.site,
      user
    }),
    userCanUpgradeSubscription: user.role === Role.owner
  })

export const DeleteAnnotationModal = ({
  annotation,
  onClose,
  onSave,
  status,
  error,
  reset
}: {
  onClose: () => void
  onSave: (input: Pick<Annotation, 'id'>) => void
  annotation: Annotation
} & ApiRequestProps) => {
  const deleteDisabled = status === 'pending'

  return (
    <ModalLayout
      title={
        <>
          Delete {ANNOTATION_TYPE_LABELS[annotation.type].toLowerCase()}
          <span className="break-all">{` "${annotation.note}"?`}</span>
        </>
      }
      onClose={onClose}
    >
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
                  onSave({ id: annotation.id })
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
              : 'Something went wrong deleting annotation'
          }
          onClose={reset}
        />
      )}
    </ModalLayout>
  )
}

export const UpdateAnnotationModal = ({
  onClose,
  onSave,
  onDelete,
  annotation,
  siteAnnotationsAvailable,
  user,
  notePlaceholder,
  status,
  error,
  reset
}: AnnotationModalProps &
  ApiRequestProps & {
    onSave: (input: Pick<Annotation, 'id' | 'note' | 'type'>) => void
    onDelete: (annotation: Annotation) => void
    annotation: Annotation
  }) => {
  const [note, setNote] = useState(annotation.note)
  const [type, setType] = useState<AnnotationType>(annotation.type)
  const trimmedNote = note.trim()

  const siteOptionDisabledMessage = getAnnotationTypeDisabledMessage({
    siteAnnotationsAvailable,
    user
  })

  const disabledMessage =
    type === AnnotationType.site ? siteOptionDisabledMessage : null

  return (
    <ModalLayout
      title={`Update note for ${formatAnnotationDatetime(annotation.datetime, annotation.granularity)}`}
      onClose={onClose}
    >
      <LabeledTextarea
        label="Note"
        id="note"
        value={note}
        onChange={setNote}
        placeholder={notePlaceholder}
        maxLength={NOTE_MAX_LENGTH}
      />
      <AnnotationTypeSelector
        value={type}
        onChange={setType}
        siteOptionDisabledMessage={siteOptionDisabledMessage}
      />
      <ModalFooter>
        <Button
          theme="danger"
          size="sm"
          className="mr-auto"
          onClick={() => onDelete(annotation)}
        >
          Delete note
        </Button>
        <Button theme="secondary" size="sm" onClick={onClose}>
          Cancel
        </Button>
        <SaveButton
          disabled={isSaveButtonDisabled({
            requestStatus: status,
            disabledMessage,
            trimmedNote
          })}
          onSave={() => onSave({ id: annotation.id, note: trimmedNote, type })}
        />
      </ModalFooter>
      {error !== null && (
        <ErrorPanel
          className="mt-4"
          errorMessage={
            error instanceof ApiError
              ? error.message
              : 'Something went wrong updating note'
          }
          onClose={reset}
        />
      )}
    </ModalLayout>
  )
}

const isSaveButtonDisabled = ({
  requestStatus,
  disabledMessage,
  trimmedNote
}: {
  requestStatus: MutationStatus
  trimmedNote: string
  disabledMessage: string | null
}) =>
  requestStatus === 'pending' ||
  isOverMaxLength(trimmedNote, NOTE_MAX_LENGTH) ||
  disabledMessage !== null ||
  !trimmedNote.length
