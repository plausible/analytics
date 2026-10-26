import React, { ReactNode, useState } from 'react'
import { ApiError } from '../../api'
import { Button } from '../../components/button'
import { ErrorPanel } from '../../components/error-panel'
import { LabeledTextInput } from '../../components/form-elements'
import {
  ModalFooter,
  ModalLayout,
  SaveButton
} from '../../components/modal-layout'

const NAME_MAX_LENGTH = 255

type RequestState = {
  pending: boolean
  error: unknown
  resetError: () => void
}

function RequestError({
  error,
  fallback,
  onClose
}: {
  error: unknown
  fallback: string
  onClose: () => void
}): ReactNode {
  if (!error) return null

  return (
    <ErrorPanel
      errorMessage={error instanceof ApiError ? error.message : fallback}
      onClose={onClose}
    />
  )
}

// Asks for the name of a funnel being saved. When editing a saved funnel,
// it can also be saved as a new one, leaving the original intact.
export function SaveFunnelModal({
  initialName,
  editing,
  onClose,
  onSave,
  pending,
  error,
  resetError
}: {
  initialName: string
  editing: boolean
  onClose: () => void
  onSave: (input: { name: string; asNew: boolean }) => void
} & RequestState): ReactNode {
  const [name, setName] = useState(initialName)
  const trimmedName = name.trim()
  const disabled = pending || trimmedName.length === 0

  return (
    <ModalLayout
      title={editing ? 'Save funnel' : 'Save as funnel'}
      onClose={onClose}
    >
      <LabeledTextInput
        id="funnel-name"
        label="Funnel name"
        focusOnMount
        value={name}
        onChange={setName}
        placeholder="e.g. From blog to signup"
        maxLength={NAME_MAX_LENGTH}
      />
      <ModalFooter>
        <Button theme="secondary" size="sm" onClick={onClose}>
          Cancel
        </Button>
        {editing && (
          <Button
            theme="secondary"
            size="sm"
            disabled={disabled}
            onClick={
              disabled
                ? () => {}
                : () => onSave({ name: trimmedName, asNew: true })
            }
          >
            Save as new
          </Button>
        )}
        <SaveButton
          disabled={disabled}
          onSave={() => onSave({ name: trimmedName, asNew: false })}
        />
      </ModalFooter>
      <RequestError
        error={error}
        fallback="Something went wrong saving the funnel"
        onClose={resetError}
      />
    </ModalLayout>
  )
}

export function DeleteFunnelModal({
  name,
  onClose,
  onDelete,
  pending,
  error,
  resetError
}: {
  name: string
  onClose: () => void
  onDelete: () => void
} & RequestState): ReactNode {
  return (
    <ModalLayout title="Delete funnel" onClose={onClose}>
      <p className="text-sm dark:text-gray-100">
        {'You’re about to delete '}
        <span className="break-all font-semibold">{`“${name}”`}</span>
        {
          '. This funnel will be removed for everyone with access to this dashboard. Are you sure?'
        }
      </p>
      <ModalFooter>
        <Button theme="secondary" size="sm" onClick={onClose}>
          Cancel
        </Button>
        <Button
          theme="danger"
          size="sm"
          disabled={pending}
          onClick={pending ? () => {} : onDelete}
        >
          Delete
        </Button>
      </ModalFooter>
      <RequestError
        error={error}
        fallback="Something went wrong deleting the funnel"
        onClose={resetError}
      />
    </ModalLayout>
  )
}
