import React, { ReactNode, useCallback, useState } from 'react'
import ModalWithRouting from '../stats/modals/modal'
import {
  canSeeSegmentDetails,
  isListableSegment,
  isSegmentFilter,
  SavedSegment,
  SEGMENT_TYPE_LABELS,
  SegmentData,
  SegmentType
} from '../filtering/segments'
import { useQueryContext } from '../query-context'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { cleanLabels } from '../util/filters'
import { plainFilterText, styledFilterText } from '../util/filter-text'
import { rootRoute } from '../router'
import { FilterPillsList } from '../nav-menu/filter-pills-list'
import classNames from 'classnames'
import { SegmentAuthorship } from './segment-authorship'
import { ExclamationTriangleIcon } from '@heroicons/react/24/outline'
import { MutationStatus } from '@tanstack/react-query'
import { ApiError } from '../api'
import { ErrorPanel } from '../components/error-panel'
import { useSegmentsContext } from '../filtering/segments-context'
import { useSiteContext } from '../site-context'
import { Role, UserContextValue, useUserContext } from '../user-context'
import { removeFilterButtonClassname } from '../components/remove-filter-button'

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

const primaryNeutralButtonClassName = 'button !px-3'

const primaryNegativeButtonClassName = classNames(
  'button !px-3',
  'items-center !bg-red-500 dark:!bg-red-500 hover:!bg-red-600 dark:hover:!bg-red-700 whitespace-nowrap'
)

const secondaryButtonClassName = classNames(
  'button !px-3',
  'border !border-gray-300 dark:!border-gray-500 !text-gray-700 dark:!text-gray-300 !bg-transparent hover:!bg-gray-100 dark:hover:!bg-gray-850'
)

const SegmentActionModal = ({
  children,
  onClose
}: {
  children: ReactNode
  onClose: () => void
}) => {
  return (
    <ModalWithRouting
      maxWidth="460px"
      className="p-6 min-h-fit"
      onClose={onClose}
    >
      <div className="mb-8 dark:text-gray-100">{children}</div>
    </ModalWithRouting>
  )
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

  const { disabled, disabledMessage, onSegmentTypeChange } =
    useSegmentTypeDisabledState({
      siteSegmentsAvailable,
      user,
      setType
    })

  return (
    <SegmentActionModal onClose={onClose}>
      <FormTitle>Create segment</FormTitle>
      <SegmentNameInput
        value={name}
        onChange={setName}
        namePlaceholder={namePlaceholder}
      />
      <SegmentTypeSelector value={type} onChange={onSegmentTypeChange} />
      {disabled && <SegmentTypeDisabledMessage message={disabledMessage} />}
      <ButtonsRow>
        <SaveSegmentButton
          disabled={status === 'pending' || disabled}
          onSave={() => {
            const trimmedName = name.trim()
            const saveableName = trimmedName.length
              ? trimmedName
              : namePlaceholder
            onSave({ name: saveableName, type })
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
              : 'Something went wrong creating segment'
          }
          onClose={reset}
        />
      )}
    </SegmentActionModal>
  )
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
  return (
    <SegmentActionModal onClose={onClose}>
      <FormTitle>
        Delete {SEGMENT_TYPE_LABELS[segment.type].toLowerCase()}
        <span className="break-all">{` "${segment.name}"?`}</span>
      </FormTitle>
      {!!segment.segment_data && (
        <FiltersInSegment segment_data={segment.segment_data} />
      )}

      <ButtonsRow>
        <button
          className={primaryNegativeButtonClassName}
          disabled={status === 'pending'}
          onClick={
            status === 'pending'
              ? () => {}
              : () => {
                  onSave({ id: segment.id })
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
              : 'Something went wrong deleting segment'
          }
          onClose={reset}
        />
      )}
    </SegmentActionModal>
  )
}

const FormTitle = ({ children }: { children?: ReactNode }) => (
  <h1 className="text-xl font-bold dark:text-gray-100 mb-2">{children}</h1>
)

const ButtonsRow = ({
  className,
  children
}: {
  className?: string
  children?: ReactNode
}) => (
  <div className={classNames('mt-8 flex gap-x-4 items-center', className)}>
    {children}
  </div>
)

const SegmentNameInput = ({
  namePlaceholder,
  value,
  onChange
}: {
  namePlaceholder: string
  value: string
  onChange: (value: string) => void
}) => {
  return (
    <>
      <label
        htmlFor="name"
        className="block text-md font-medium text-gray-700 dark:text-gray-300"
      >
        Segment name
      </label>
      <input
        autoComplete="off"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={namePlaceholder}
        id="name"
        className="block mt-2 p-2 w-full dark:bg-gray-900 dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500"
      />
    </>
  )
}

const SegmentTypeSelector = ({
  value,
  onChange
}: {
  value: SegmentType
  onChange: (value: SegmentType) => void
}) => {
  const options = [
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
  ]

  return (
    <div className="mt-4 flex flex-col gap-y-4">
      {options.map(({ type, name, description }) => (
        <div key={type}>
          <div className="flex">
            <input
              checked={value === type}
              id={`segment-type-${type}`}
              type="radio"
              value=""
              onChange={() => onChange(type)}
              className="mt-4 w-4 h-4 text-indigo-600 bg-gray-100 border-gray-300 focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 dark:border-gray-600"
            />
            <label
              htmlFor={`segment-type-${type}`}
              className="ml-3 text-sm font-medium text-gray-900 dark:text-gray-300"
            >
              <div className="font-bold">{name}</div>
              <div className="mt-1">{description}</div>
            </label>
          </div>
        </div>
      ))}
    </div>
  )
}

const useSegmentTypeDisabledState = ({
  siteSegmentsAvailable,
  user,
  setType
}: {
  siteSegmentsAvailable: boolean
  user: UserContextValue
  setType: (type: SegmentType) => void
}) => {
  const [disabled, setDisabled] = useState<boolean>(false)
  const [disabledMessage, setDisabledMessage] = useState<ReactNode | null>(null)

  const userIsOwner = user.role === Role.owner
  const canSelectSiteSegment = hasSiteSegmentPermission(user)

  const onSegmentTypeChange = useCallback(
    (type: SegmentType) => {
      setType(type)

      if (type === SegmentType.site && !canSelectSiteSegment) {
        setDisabled(true)
        setDisabledMessage(
          <>
            {"You don't have enough permissions to change segment to this type"}
          </>
        )
      } else if (type === SegmentType.site && !siteSegmentsAvailable) {
        setDisabled(true)
        setDisabledMessage(
          <>
            To use this segment type,&#32;
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
    [setType, siteSegmentsAvailable, userIsOwner, canSelectSiteSegment]
  )

  return {
    disabled,
    disabledMessage,
    onSegmentTypeChange
  }
}

const SaveSegmentButton = ({
  disabled,
  onSave
}: {
  disabled: boolean
  onSave: () => void
}) => {
  return (
    <button
      className={primaryNeutralButtonClassName}
      type="button"
      disabled={disabled}
      onClick={disabled ? () => {} : onSave}
    >
      Save
    </button>
  )
}

const SegmentTypeDisabledMessage = ({
  message
}: {
  message: ReactNode | null
}) => {
  if (!message) return null

  return (
    <div className="mt-2 flex gap-x-2 text-sm">
      <ExclamationTriangleIcon className="mt-1 block w-4 h-4 shrink-0" />
      <div>{message}</div>
    </div>
  )
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

  const { disabled, disabledMessage, onSegmentTypeChange } =
    useSegmentTypeDisabledState({
      siteSegmentsAvailable,
      user,
      setType
    })

  return (
    <SegmentActionModal onClose={onClose}>
      <FormTitle>Update segment</FormTitle>
      <SegmentNameInput
        value={name}
        onChange={setName}
        namePlaceholder={namePlaceholder}
      />
      <SegmentTypeSelector value={type} onChange={onSegmentTypeChange} />
      {disabled && <SegmentTypeDisabledMessage message={disabledMessage} />}
      <ButtonsRow>
        <SaveSegmentButton
          disabled={status === 'pending' || disabled}
          onSave={() => {
            const trimmedName = name.trim()
            const saveableName = trimmedName.length
              ? trimmedName
              : namePlaceholder
            onSave({ id: segment.id, name: saveableName, type })
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
    </SegmentActionModal>
  )
}

const FiltersInSegment = ({ segment_data }: { segment_data: SegmentData }) => {
  return (
    <>
      <h2 className="font-bold dark:text-gray-100">Filters in segment</h2>
      <div className="mt-2">
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
    </>
  )
}

const Placeholder = ({
  children,
  placeholder
}: {
  children: ReactNode | false
  placeholder: ReactNode
}) => (
  <span
    className={classNames(
      'rounded',
      children === false &&
        'bg-gray-100 dark:bg-gray-700 text-gray-100 dark:text-gray-700'
    )}
  >
    {children === false ? placeholder : children}
  </span>
)

const hasSiteSegmentPermission = (user: UserContextValue) => {
  return [Role.admin, Role.owner, Role.editor, 'super_admin'].includes(
    user.role
  )
}

export const SegmentModal = ({ id }: { id: SavedSegment['id'] }) => {
  const site = useSiteContext()
  const user = useUserContext()
  const { query } = useQueryContext()
  const { segments } = useSegmentsContext()

  const segment = segments
    .filter((s) => isListableSegment({ segment: s, site, user }))
    .find((s) => String(s.id) === String(id))

  let error: ApiError | null = null

  if (!segment) {
    error = new ApiError(`Segment not found with with ID "${id}"`, {
      error: `Segment not found with with ID "${id}"`
    })
  } else if (!canSeeSegmentDetails({ user })) {
    error = new ApiError('Not enough permissions to see segment details', {
      error: `Not enough permissions to see segment details`
    })
  }

  const data = !error ? segment : null

  return (
    <ModalWithRouting maxWidth="460px">
      <div className="dark:text-gray-100 mb-8">
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-x-2">
            <h1 className="text-xl font-bold break-all">
              {data ? data.name : 'Segment details'}
            </h1>
          </div>
        </div>

        <div className="mt-2 text-sm/5">
          <Placeholder placeholder={'Segment type'}>
            {data?.segment_data ? SEGMENT_TYPE_LABELS[data.type] : false}
          </Placeholder>
        </div>
        <div className="my-4 border-b border-gray-300" />
        {!!data?.segment_data && (
          <>
            <FiltersInSegment segment_data={data.segment_data} />

            <SegmentAuthorship
              segment={data}
              showOnlyPublicData={false}
              className="mt-4 text-sm"
            />
            <div className="mt-4">
              <ButtonsRow>
                <AppNavigationLink
                  className={primaryNeutralButtonClassName}
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

                <AppNavigationLink
                  className={removeFilterButtonClassname}
                  path={rootRoute.path}
                  search={(s) => {
                    const nonSegmentFilters = query.filters.filter(
                      (f) => !isSegmentFilter(f)
                    )
                    return {
                      ...s,
                      filters: nonSegmentFilters,
                      labels: cleanLabels(
                        nonSegmentFilters,
                        query.labels,
                        'segment',
                        {}
                      )
                    }
                  }}
                >
                  Remove filter
                </AppNavigationLink>
              </ButtonsRow>
            </div>
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
    </ModalWithRouting>
  )
}
