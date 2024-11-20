/** @format */

import React, { ReactNode, useMemo, useState } from 'react'
import ModalWithRouting from '../stats/modals/modal'
import classNames from 'classnames'
import {
  formatSegmentIdAsLabelKey,
  getFilterSegmentsByNameInsensitive,
  isSegmentFilter,
  SavedSegment,
  SegmentType
} from './segments'
import { ColumnConfiguraton, Table } from '../components/table'
import {
  ExpandSegment,
  useSegmentPrefetch,
  useSegmentsListQuery
} from './segments-dropdown'
import { SearchInput } from '../components/search-input'
import { useQueryContext } from '../query-context'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { cleanLabels } from '../util/filters'
import { rootRoute } from '../router'
// import { ArrowsPointingOutIcon } from '@heroicons/react/24/solid'

const buttonClass =
  'h-12 text-md font-medium py-2 px-3 rounded border dark:border-gray-100 dark:text-gray-100'

const ExpandSegmentButton = ({ id }: Pick<SavedSegment, 'id'>) => {
  const { prefetchSegment, expandSegment } = useSegmentPrefetch({ id })
  return (
    <ExpandSegment onClick={expandSegment} onMouseEnter={prefetchSegment} />
  )
}

const SegmentActionModal = ({
  children,
  onClose
}: {
  children: ReactNode
  onClose: () => void
}) => (
  <ModalWithRouting
    maxWidth="460px"
    className="p-6 min-h-fit"
    onClose={onClose}
  >
    {children}
  </ModalWithRouting>
)

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
        <button className={buttonClass} onClick={onClose}>
          Cancel
        </button>
        <button
          className={buttonClass}
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
  segment: SavedSegment
}) => {
  return (
    <SegmentActionModal onClose={onClose}>
      <h1 className="text-xl font-extrabold	dark:text-gray-100">
        {
          { personal: 'Delete personal segment', site: 'Delete site segment' }[
            segment.type
          ]
        }
        {` "${segment.name}"?`}
      </h1>
      <ButtonsRow>
        <button className={buttonClass} onClick={onClose}>
          Cancel
        </button>
        <button
          className={buttonClass}
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
  <h1 className="text-xl font-extrabold	dark:text-gray-100">{children}</h1>
)

const ButtonsRow = ({ children }: { children?: ReactNode }) => (
  <div className="mt-8 flex gap-x-2 items-center justify-end">{children}</div>
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
        className="block mt-2 text-md font-medium text-gray-700 dark:text-gray-300"
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
      <div className="mt-1 text-sm">
        Add a name to your segment to make it easier to find
      </div>
    </>
  )
}

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
    <div className="mt-4 flex items-center">
      <button
        className={classNames(
          'relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full transition-colors ease-in-out duration-200 focus:outline-none focus:ring',
          value === SegmentType.personal
            ? 'bg-gray-200 dark:bg-gray-700'
            : 'bg-indigo-600',
          disabled && 'cursor-not-allowed'
        )}
        onClick={
          disabled
            ? () => {}
            : () =>
                onChange(
                  value === SegmentType.personal
                    ? SegmentType.site
                    : SegmentType.personal
                )
        }
      >
        <span
          aria-hidden="true"
          className={classNames(
            'inline-block h-5 w-5 rounded-full bg-white dark:bg-gray-800 shadow transform transition ease-in-out duration-200',
            value === SegmentType.personal ? 'translate-x-0' : 'translate-x-5'
          )}
        />
      </button>
      <span className="ml-2 font-medium leading-5 text-sm text-gray-900 dark:text-gray-100">
        Show this segment for all site users
      </span>
    </div>
  </>
)

export const UpdateSegmentModal = ({
  close,
  onSave,
  segment,
  canTogglePersonal,
  namePlaceholder
}: {
  close: () => void
  onSave: (input: Pick<SavedSegment, 'id' | 'name' | 'type'>) => void
  segment: SavedSegment
  canTogglePersonal: boolean
  namePlaceholder: string
}) => {
  const [name, setName] = useState(segment.name)
  const [type, setType] = useState<SegmentType>(segment.type)

  return (
    <ModalWithRouting maxWidth="460px" className="p-6 min-h-fit" close={close}>
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
        <button className={buttonClass} onClick={close}>
          Cancel
        </button>
        <button
          className={buttonClass}
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
    </ModalWithRouting>
  )
}

export const AllSegmentsModal = () => {
  const { query } = useQueryContext()
  const querySegmentIds: number[] =
    (query.filters.find(isSegmentFilter)?.[2] as number[]) ?? []
  const { data } = useSegmentsListQuery()
  const [search, setSearch] = useState<string>()
  const [selectedSegmentIds, setSelectedSegmentIds] =
    useState<number[]>(querySegmentIds)

  const columns: ColumnConfiguraton<SavedSegment & { selected?: boolean }>[] =
    useMemo(
      () => [
        {
          key: 'name',
          label: 'Name',
          width: 'w-60',
          align: 'left',
          renderItem: ({ id, name, selected }) => (
            <button
              className={classNames('w-full text-left', {
                'font-extrabold': selected
              })}
              onClick={() =>
                setSelectedSegmentIds((current) =>
                  current.includes(id)
                    ? current.filter((selectedId) => selectedId !== id)
                    : current.concat([id])
                )
              }
            >
              {name}
              {!!selected && ' ✓'}
            </button>
          )
        },
        {
          key: 'type',
          label: 'Type',
          width: 'w-20',
          align: 'right',
          renderValue: ({ type }) =>
            ({ personal: 'Personal', site: 'Site' })[type]
        },
        {
          key: 'owner_id',
          width: 'w-8',
          align: 'right',
          label: '',
          renderItem: ExpandSegmentButton
        }
      ],
      []
    )

  return (
    <ModalWithRouting maxWidth="460px" className="p-6 min-h-fit">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-x-2">
          <h1 className="text-xl font-bold dark:text-gray-100">Segments</h1>
        </div>
        <SearchInput onSearch={(v) => setSearch(v)} />
      </div>
      <div className="my-4 border-b border-gray-300"></div>
      <div>
        <Table
          columns={columns}
          data={
            data
              ?.map((i) => ({
                ...i,
                selected: selectedSegmentIds.includes(i.id)
              }))
              .filter(getFilterSegmentsByNameInsensitive(search)) ?? []
          }
        />
        <div className="mt-6 flex items-center justify-start">
          <AppNavigationLink
            className="button"
            path={rootRoute.path}
            search={(s) => {
              const nonSegmentFilters = query.filters.filter(
                (f) => !isSegmentFilter(f)
              )
              if (!selectedSegmentIds.length) {
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
              }
              const filters = nonSegmentFilters.concat([
                ['is', 'segment', selectedSegmentIds]
              ])
              const labels = cleanLabels(
                filters,
                query.labels,
                'segment',
                Object.fromEntries(
                  selectedSegmentIds.map((id) => [
                    formatSegmentIdAsLabelKey(id),
                    data?.find((i) => i.id === id)?.name ?? ''
                  ])
                )
              )
              return {
                ...s,
                filters,
                labels
              }
            }}
          >
            Apply Segments
          </AppNavigationLink>
        </div>
      </div>
    </ModalWithRouting>
  )
}
