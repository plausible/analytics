/** @format */

import React, { ReactNode, useCallback, useState } from 'react'
import ModalWithRouting from '../stats/modals/modal'
import {
  formatSegmentIdAsLabelKey,
  getFilterSegmentsByNameInsensitive,
  isSegmentFilter,
  SavedSegment,
  SegmentType
} from './segments'
import {
  EditSegment,
  useSegmentPrefetch,
  useSegmentsListQuery
} from './segments-dropdown'
import { SearchInput } from '../components/search-input'
import { useQueryContext } from '../query-context'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { cleanLabels, plainFilterText, styledFilterText } from '../util/filters'
import { rootRoute } from '../router'
import { FilterPillsList } from '../nav-menu/filter-pills-list'
import classNames from 'classnames'
import {
  EyeSlashIcon,
  EyeIcon,
  XMarkIcon,
  CheckIcon
} from '@heroicons/react/24/solid'
import { FilterPill } from '../nav-menu/filter-pill'
import { Filter } from '../query'
import { SegmentAuthorship } from './segment-authorship'

const buttonClass =
  'h-12 text-md font-medium py-2 px-3 rounded border dark:border-gray-100 dark:text-gray-100'

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
    <div className="mt-4">
      <div className="flex items-center">
        <input
          checked={value === SegmentType.personal}
          id="segment-type-personal"
          type="radio"
          value=""
          onClick={() => onChange(SegmentType.personal)}
          className="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
          disabled={disabled}
        />
        <label
          htmlFor="segment-type-personal"
          className="ms-3 text-sm font-medium text-gray-900 dark:text-gray-300"
        >
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
          onClick={() => onChange(SegmentType.site)}
          className="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
          disabled={disabled}
        />
        <label
          htmlFor="segment-type-site"
          className="ms-3 text-sm font-medium text-gray-900 dark:text-gray-300"
        >
          <div className="font-bold">Site segment</div>
          <div className="mt-1">Visible to others on the site</div>
        </label>
      </div>
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

const ExpandSegmentButton = ({
  className,
  onClick,
  onMouseEnter,
  expanded
}: {
  className?: string
  onClick: () => Promise<void>
  onMouseEnter?: () => Promise<void>
  expanded: boolean
}) => {
  return (
    <button
      className={classNames(
        'block w-4 h-4 fill-current hover:fill-indigo-600',
        className
      )}
      onClick={onClick}
      onMouseEnter={onMouseEnter}
    >
      {expanded ? (
        <EyeSlashIcon className="block w-4 h-4" />
      ) : (
        <EyeIcon className="block w-4 h-4" />
      )}
    </button>
  )
}
const SegmentRow = ({
  id,
  name,
  type,
  toggleSelected,
  selected
}: SavedSegment & { toggleSelected: () => void; selected: boolean }) => {
  const { prefetchSegment, data, expandSegment, fetchSegment } =
    useSegmentPrefetch({
      id
    })
  const [segmentDataVisible, setSegmentDataVisible] = useState(false)

  return (
    <div
      className="grid grid-cols-[1fr_20px_20px] shadow rounded bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 text-sm py-3 px-3 transition-all"
      onMouseEnter={prefetchSegment}
    >
      {/* <button className="block" onClick={toggleSelected}>
        {selected && <CheckIcon className="block w-4 h-4" />}
      </button> */}
      <div onClick={toggleSelected} className={classNames(selected && 'font-bold')}>
        {name}
        {/* <span>{' · '}</span> */}
        {/* <span className="text-[10px] leading">
          {{ personal: 'personal', site: 'site' }[type]}
        </span> */}
      </div>
      <ExpandSegmentButton
        className=""
        expanded={segmentDataVisible}
        onClick={
          segmentDataVisible
            ? async () => setSegmentDataVisible(false)
            : async () => {
                setSegmentDataVisible(true)
                fetchSegment()
              }
        }
      ></ExpandSegmentButton>
      <EditSegment
        onClick={async () => {
          expandSegment(data ?? (await fetchSegment()))
        }}
      />

      {segmentDataVisible && (
        <div className="col-span-full mt-3">
          {data?.segment_data ? (
            <FilterPillsList
              className="flex-wrap"
              direction="horizontal"
              pills={data.segment_data.filters.map((filter) => ({
                plainText: plainFilterText(data.segment_data.labels, filter),
                children: styledFilterText(data.segment_data.labels, filter),
                interactive: false
              }))}
            />
          ) : (
            'loading'
          )}
          <SegmentAuthorship {...data} className="mt-3 text-xs" />
        </div>
      )}
    </div>
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
  const getToggleSelected = useCallback(
    (id: number) => () =>
      setSelectedSegmentIds((current) =>
        current.includes(id)
          ? current.filter((i) => i !== id)
          : current.concat([id])
      ),
    []
  )

  const proposedSegmentFilter: Filter | null = selectedSegmentIds.length
    ? ['is', 'segment', selectedSegmentIds]
    : null

  const labelsForProposedSegmentFilter = !data
    ? {}
    : Object.fromEntries(
        data?.flatMap((d) =>
          selectedSegmentIds.includes(d.id)
            ? [[formatSegmentIdAsLabelKey(d.id), d.name]]
            : []
        )
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

      <div className="flex flex-col gap-y-2">
        {(data?.filter(getFilterSegmentsByNameInsensitive(search)) ?? []).map(
          (item) => (
            <SegmentRow
              key={item.id}
              {...item}
              toggleSelected={getToggleSelected(item.id)}
              selected={selectedSegmentIds.includes(item.id)}
            />
          )
        )}
      </div>
      <div className="my-4 border-b border-gray-300"></div>

      <div>
        {!!data && !!proposedSegmentFilter && (
          <div className="mt-4 justify-self-start">
            {/* <FilterPillsList
              className="flex-wrap"
              direction="horizontal"
              pills={proposedSegmentFilter[2].map((c) => ({
                children: styledFilterText(labelsForProposedSegmentFilter, [
                  proposedSegmentFilter[0],
                  proposedSegmentFilter[1],
                  [c]
                ]),
                plainText: 'hi',
                interactive: false
              }))}
            /> */}
            <FilterPill
              interactive={false}
              plainText={plainFilterText(
                labelsForProposedSegmentFilter,
                proposedSegmentFilter
              )}
              actions={
                <button
                  title={`Remove filter: ${plainFilterText(labelsForProposedSegmentFilter, proposedSegmentFilter)}`}
                  className="flex items-center h-full px-2 mr-1 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 "
                  onClick={() => setSelectedSegmentIds([])}
                >
                  <XMarkIcon className="block w-4 h-4" />
                </button>
              }
            >
              {styledFilterText(
                labelsForProposedSegmentFilter,
                proposedSegmentFilter
              )}
            </FilterPill>
          </div>
        )}
        <div className="mt-6 flex items-center justify-start gap-x-2">
          <AppNavigationLink
            className="button"
            path={rootRoute.path}
            search={(s) => {
              const nonSegmentFilters = query.filters.filter(
                (f) => !isSegmentFilter(f)
              )
              if (!proposedSegmentFilter) {
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
              const filters = nonSegmentFilters.concat([proposedSegmentFilter])
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
            Apply selected
          </AppNavigationLink>
          <AppNavigationLink
            className="button bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700"
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
            Clear selected
          </AppNavigationLink>
        </div>
      </div>
    </ModalWithRouting>
  )
}
