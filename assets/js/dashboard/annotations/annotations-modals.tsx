import React, { ReactNode, useCallback, useState } from 'react'
import {
  Annotation,
  ANNOTATION_TYPE_LABELS,
  AnnotationPayload,
  AnnotationType
} from './annotations'
import { MutationStatus } from '@tanstack/react-query'
import { ApiError } from '../api'
import { ErrorPanel } from '../components/error-panel'
import {
  ActionModal,
  ButtonsRow,
  FormTitle,
  LabeledTextInput,
  primaryNegativeButtonClassName,
  SaveButton,
  secondaryButtonClassName,
  TypeDisabledMessage,
  TypeSelector
} from '../components/action-modal'
import { Role, UserContextValue } from '../user-context'

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
  const defaultNote = ''
  const [note, setNote] = useState(defaultNote)
  const granularity = initialGranularity
  const datetime = initialDatetime
  const type = initialType

  return (
    <ActionModal onClose={onClose}>
      <FormTitle className="mb-8">Add note for {datetime}</FormTitle>
      <LabeledTextInput
        label="Note"
        id="note"
        value={note}
        onChange={setNote}
        placeholder={notePlaceholder}
      />
      <ButtonsRow>
        <SaveButton
          disabled={status === 'pending'}
          onSave={() => {
            const trimmedNote = note.trim()
            const saveableNote = trimmedNote.length
              ? trimmedNote
              : notePlaceholder

            onSave({
              note: saveableNote,
              type,
              datetime,
              granularity
            })
          }}
        />
        <button className={secondaryButtonClassName} onClick={onClose}>
          Cancel
        </button>
      </ButtonsRow>
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
    </ActionModal>
  )
}

const AnnotationTypeSelector = ({
  value,
  onChange
}: {
  value: AnnotationType
  onChange: (value: AnnotationType) => void
}) => {
  const options = [
    {
      type: AnnotationType.personal,
      name: ANNOTATION_TYPE_LABELS[AnnotationType.personal],
      description: 'Visible only to you'
    },
    {
      type: AnnotationType.site,
      name: ANNOTATION_TYPE_LABELS[AnnotationType.site],
      description: 'Visible to others on the site'
    }
  ]

  return (
    <TypeSelector<AnnotationType>
      value={value}
      onChange={onChange}
      options={options}
    />
  )
}

const useAnnotationTypeDisabledState = ({
  siteAnnotationsAvailable,
  user,
  setType
}: {
  siteAnnotationsAvailable: boolean
  user: UserContextValue
  setType: (type: AnnotationType) => void
}) => {
  const [disabled, setDisabled] = useState<boolean>(false)
  const [disabledMessage, setDisabledMessage] = useState<ReactNode | null>(null)

  const userIsOwner = user.role === Role.owner
  const canSelectSiteAnnotation = [
    Role.admin,
    Role.owner,
    Role.editor,
    'super_admin'
  ].includes(user.role)

  const onAnnotationTypeChange = useCallback(
    (type: AnnotationType) => {
      setType(type)

      if (type === AnnotationType.site && !canSelectSiteAnnotation) {
        setDisabled(true)
        setDisabledMessage(
          <>
            {"You don't have enough permissions to change segment to this type"}
          </>
        )
      } else if (type === AnnotationType.site && !siteAnnotationsAvailable) {
        setDisabled(true)
        setDisabledMessage(
          <>
            To use this annotation type,&#32;
            {userIsOwner ? (
              <a href="/billing/choose-plan" className="underline">
                please upgrade your subscription
              </a>
            ) : (
              <>
                please reach out to a team owner to upgrade their subscription.
              </>
            )}
          </>
        )
      } else {
        setDisabled(false)
        setDisabledMessage(null)
      }
    },
    [setType, siteAnnotationsAvailable, userIsOwner, canSelectSiteAnnotation]
  )

  return {
    disabled,
    disabledMessage,
    onAnnotationTypeChange
  }
}

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
    <ActionModal onClose={onClose}>
      <FormTitle className="mb-4">
        Delete {ANNOTATION_TYPE_LABELS[annotation.type].toLowerCase()}
        <span className="break-all">{` "${annotation.note}"?`}</span>
      </FormTitle>
      <ButtonsRow>
        <button
          className={primaryNegativeButtonClassName}
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
        </button>
        <button className={secondaryButtonClassName} onClick={onClose}>
          Cancel
        </button>
      </ButtonsRow>
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
    </ActionModal>
  )
}

export const UpdateAnnotationModal = ({
  onClose,
  onSave,
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
    annotation: Annotation
  }) => {
  const [note, setNote] = useState(annotation.note)
  const [type, setType] = useState<AnnotationType>(annotation.type)

  const { disabled, disabledMessage, onAnnotationTypeChange } =
    useAnnotationTypeDisabledState({
      siteAnnotationsAvailable,
      user,
      setType
    })

  return (
    <ActionModal onClose={onClose}>
      <FormTitle className="mb-8">Update note</FormTitle>
      <LabeledTextInput
        label="Note"
        id="note"
        value={note}
        onChange={setNote}
        placeholder={notePlaceholder}
      />
      <AnnotationTypeSelector value={type} onChange={onAnnotationTypeChange} />
      {disabled && <TypeDisabledMessage message={disabledMessage} />}
      <ButtonsRow>
        <SaveButton
          disabled={status === 'pending' || disabled}
          onSave={() => {
            const trimmedNote = note.trim()
            const saveableNote = trimmedNote.length
              ? trimmedNote
              : notePlaceholder
            onSave({ id: annotation.id, note: saveableNote, type })
          }}
        />
        <button className={secondaryButtonClassName} onClick={onClose}>
          Cancel
        </button>
      </ButtonsRow>
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
    </ActionModal>
  )
}
