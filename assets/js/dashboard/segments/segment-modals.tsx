/** @format */

import React, { ReactNode, useLayoutEffect, useState } from 'react'
import ModalWithRouting from '../stats/modals/modal'
import {
  isSegmentFilter,
  SavedSegment,
  SegmentData,
  SegmentType
} from '../filtering/segments'
import { useSegmentPrefetch } from './segments-dropdown'
import { useQueryContext } from '../query-context'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { cleanLabels } from '../util/filters'
import { plainFilterText, styledFilterText } from '../util/filter-text'
import { rootRoute } from '../router'
import { FilterPillsList } from '../nav-menu/filter-pills-list'
import classNames from 'classnames'
import { SegmentAuthorship } from './segment-authorship'
import { BUFFER_FOR_SHADOW_PX } from '../nav-menu/filter-pill'

export const buttonClass =
  'transition border text-md font-medium py-3 px-4 rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500'

export const primaryNeutralButtonClass = classNames(
  buttonClass,
  'bg-indigo-600 hover:bg-indigo-700 text-white border-transparent'
)

const primaryNegativeButtonClass = classNames(
  buttonClass,
  'border-transparent bg-red-500 hover:bg-red-600 text-white border-transparent'
)

export const secondaryButtonClass = classNames(
  buttonClass,
  'border-indigo-500 text-indigo-500 hover:border-indigo-600 hover:text-indigo-600',
  'dark:hover:border-indigo-400 dark:hover:text-indigo-400'
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
      {children}
    </ModalWithRouting>
  )
}

export const CreateSegmentModal = ({
  segment,
  onClose,
  onSave,
  canTogglePersonal,
  namePlaceholder
}: {
  segment?: SavedSegment
  onClose: () => void
  onSave: (input: Pick<SavedSegment, 'name' | 'type'>) => void
  canTogglePersonal: boolean
  namePlaceholder: string
}) => {
  const [name, setName] = useState(
    segment?.name ? `Copy of ${segment.name}` : ''
  )
  const [type, setType] = useState<SegmentType>(
    segment?.type === SegmentType.site && canTogglePersonal
      ? SegmentType.site
      : SegmentType.personal
  )

  return (
    <SegmentActionModal onClose={onClose}>
      <FormTitle>Create segment</FormTitle>
      <SegmentNameInput
        value={name}
        onChange={setName}
        namePlaceholder={namePlaceholder}
      />
      <SegmentTypeInput
        value={type}
        onChange={setType}
        disabled={!canTogglePersonal}
      />
      <ButtonsRow>
        <button className={secondaryButtonClass} onClick={onClose}>
          Cancel
        </button>
        <button
          className={primaryNeutralButtonClass}
          onClick={() => {
            const trimmedName = name.trim()
            const saveableName = trimmedName.length
              ? trimmedName
              : namePlaceholder
            onSave({ name: saveableName, type })
          }}
        >
          Save
        </button>
      </ButtonsRow>
    </SegmentActionModal>
  )
}

export const DeleteSegmentModal = ({
  onClose,
  onSave,
  segment
}: {
  onClose: () => void
  onSave: (input: Pick<SavedSegment, 'id'>) => void
  segment: SavedSegment & { segment_data?: SegmentData }
}) => {
  return (
    <SegmentActionModal onClose={onClose}>
      <FormTitle>
        {
          { personal: 'Delete personal segment', site: 'Delete site segment' }[
            segment.type
          ]
        }
        <span className="break-all">{` "${segment.name}"?`}</span>
      </FormTitle>
      {segment.segment_data && (
        <FiltersInSegment segment_data={segment.segment_data} />
      )}

      <ButtonsRow>
        <button className={secondaryButtonClass} onClick={onClose}>
          Cancel
        </button>
        <button
          className={primaryNegativeButtonClass}
          onClick={() => {
            onSave({ id: segment.id })
          }}
        >
          Delete
        </button>
      </ButtonsRow>
    </SegmentActionModal>
  )
}

const FormTitle = ({ children }: { children?: ReactNode }) => (
  <h1 className="text-xl font-extrabold	dark:text-gray-100 mb-2">{children}</h1>
)

const ButtonsRow = ({ children }: { children?: ReactNode }) => (
  <div className="mt-8 flex gap-x-4 items-center justify-end">{children}</div>
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

const radioClassName =
  'w-4 h-4 text-indigo-600 bg-gray-100 border-gray-300 focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 dark:border-gray-600'
const radioLabelClassName =
  'ms-3 text-sm font-medium text-gray-900 dark:text-gray-300'
const SegmentTypeInput = ({
  value,
  onChange,
  disabled
}: {
  value: SegmentType
  onChange: (value: SegmentType) => void
  disabled?: boolean
}) => (
  <>
    <div className="mt-4">
      <div className="flex items-center">
        <input
          checked={value === SegmentType.personal}
          id="segment-type-personal"
          type="radio"
          value=""
          onChange={() => onChange(SegmentType.personal)}
          className={radioClassName}
          disabled={disabled}
        />
        <label htmlFor="segment-type-personal" className={radioLabelClassName}>
          <div className="font-bold">Personal segment</div>
          <div className="mt-1">Visible only to you</div>
        </label>
      </div>
      <div className="flex items-center mt-4">
        <input
          checked={value === SegmentType.site}
          id="segment-type-site"
          type="radio"
          value=""
          onChange={() => onChange(SegmentType.site)}
          className={radioClassName}
          disabled={disabled}
        />
        <label htmlFor="segment-type-site" className={radioLabelClassName}>
          <div className="font-bold">Site segment</div>
          <div className="mt-1">Visible to others on the site</div>
        </label>
      </div>
    </div>
  </>
)

export const UpdateSegmentModal = ({
  onClose,
  onSave,
  segment,
  canTogglePersonal,
  namePlaceholder
}: {
  onClose: () => void
  onSave: (input: Pick<SavedSegment, 'id' | 'name' | 'type'>) => void
  segment: SavedSegment
  canTogglePersonal: boolean
  namePlaceholder: string
}) => {
  const [name, setName] = useState(segment.name)
  const [type, setType] = useState<SegmentType>(segment.type)

  return (
    <SegmentActionModal onClose={onClose}>
      <FormTitle>Update segment</FormTitle>
      <SegmentNameInput
        value={name}
        onChange={setName}
        namePlaceholder={namePlaceholder}
      />
      <SegmentTypeInput
        value={type}
        onChange={setType}
        disabled={!canTogglePersonal}
      />
      <ButtonsRow>
        <button className={secondaryButtonClass} onClick={onClose}>
          Cancel
        </button>
        <button
          className={primaryNeutralButtonClass}
          onClick={() => {
            const trimmedName = name.trim()
            const saveableName = trimmedName.length
              ? trimmedName
              : namePlaceholder
            onSave({ id: segment.id, name: saveableName, type })
          }}
        >
          Save
        </button>
      </ButtonsRow>
    </SegmentActionModal>
  )
}

const FiltersInSegment = ({ segment_data }: { segment_data: SegmentData }) => {
  return (
    <>
      <h2 className="font-medium dark:text-gray-100">Filters in segment</h2>
      <FilterPillsList
        style={{
          marginLeft: -BUFFER_FOR_SHADOW_PX,
          marginRight: -BUFFER_FOR_SHADOW_PX
        }}
        className="mt-2 flex-wrap"
        direction="horizontal"
        pills={segment_data.filters.map((filter) => ({
          // className: 'dark:!bg-gray-700',
          plainText: plainFilterText({ labels: segment_data.labels }, filter),
          children: styledFilterText({ labels: segment_data.labels }, filter),
          interactive: false
        }))}
      />
    </>
  )
}

export const AllSegmentsModal = () => {
  const { query } = useQueryContext()
  const segmentsFilter = query.filters.find(isSegmentFilter)!
  const { data, fetchSegment } = useSegmentPrefetch({
    id: String(segmentsFilter[2][0])
  })
  useLayoutEffect(() => {
    fetchSegment()
  }, [fetchSegment])

  return (
    <ModalWithRouting maxWidth="460px">
      <div className="dark:text-gray-100">
        <div className="flex justify-between items-center dark:text-gray-100">
          <div className="flex items-center gap-x-2">
            <h1 className="text-xl font-bold dark:text-gray-100">
              {data ? data.name : 'Segment'}
            </h1>
          </div>
        </div>
        <div className="my-4 border-b border-gray-300" />
        {data?.segment_data ? (
          <>
            <FiltersInSegment segment_data={data.segment_data} />
            <div className="mt-2 text-sm">
              {
                {
                  [SegmentType.personal]: 'Personal segment',
                  [SegmentType.site]: 'Site segment'
                }[data.type]
              }
            </div>

            <SegmentAuthorship {...data} className="mt-2 text-sm" />
            <div className="mt-4">
              <ButtonsRow>
                <AppNavigationLink
                  className={primaryNegativeButtonClass}
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

                <AppNavigationLink
                  className={primaryNeutralButtonClass}
                  path={rootRoute.path}
                  search={(s) => ({
                    ...s,
                    filters: data.segment_data.filters,
                    labels: data.segment_data.labels
                  })}
                  state={{
                    expandedSegment: data,
                    modal: null
                  }}
                >
                  Edit segment
                </AppNavigationLink>
              </ButtonsRow>
            </div>
          </>
        ) : (
          <div className="loading sm" />
        )}
      </div>
    </ModalWithRouting>
  )
}
