/** @format */

import React, { ReactNode, useCallback, useEffect, useState } from 'react'
import ModalWithRouting from '../stats/modals/modal'
import {
  formatSegmentIdAsLabelKey,
  getFilterSegmentsByNameInsensitive,
  isSegmentFilter,
  SavedSegment,
  SegmentData,
  SegmentType
} from './segments'
import {
  EditSegmentIcon,
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
  ChevronUpIcon,
  ChevronDownIcon,
} from '@heroicons/react/24/outline'
import { Filter } from '../query'
import { SegmentAuthorship } from './segment-authorship'

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
      {segment?.segment_data && (
        <FilterPillsList
          className="flex-wrap"
          direction="horizontal"
          pills={segment.segment_data.filters.map((filter) => ({
            // className: 'dark:!bg-gray-700',
            plainText: plainFilterText(segment.segment_data!.labels, filter),
            children: styledFilterText(segment.segment_data!.labels, filter),
            interactive: false
          }))}
        />
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
  <h1 className="text-xl font-extrabold	dark:text-gray-100">{children}</h1>
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
        <button className={secondaryButtonClass} onClick={close}>
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
    </ModalWithRouting>
  )
}

const SegmentRow = ({
  id,
  name,
  toggleSelected,
  selected,

  segmentDataVisible,
  toggleSegmentDataVisible
}: SavedSegment & {
  toggleSelected: () => void
  selected: boolean
  segmentDataVisible: boolean
  toggleSegmentDataVisible: () => void
}) => {
  const { prefetchSegment, data, expandSegment, fetchSegment } =
    useSegmentPrefetch({
      id
    })
  // const [segmentDataVisible, setSegmentDataVisible] = useState(false)
  // const toggleSegmentDataVisible = useCallback(async () => {
  //   setSegmentDataVisible((currentVisible) => {
  //     if (currentVisible) {
  //       return false
  //     }
  //     fetchSegment()
  //     return true
  //   })
  // }, [fetchSegment])
  useEffect(() => {
    if (segmentDataVisible) {
      fetchSegment()
    }
  }, [segmentDataVisible, fetchSegment])
  return (
    <div
      className="grid grid-cols-[1fr_20px] gap-x-2 shadow rounded bg-white dark:bg-gray-900 text-gray-700 dark:text-gray-300 text-sm py-3 px-3 transition-all"
      onMouseEnter={prefetchSegment}
    >
      <div className="flex gap-x-2 text-left">
        <input
          id={String(id)}
          type="checkbox"
          checked={selected}
          value=""
          onChange={toggleSelected}
          className="my-0.5 w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
        />
        <label
          htmlFor={String(id)}
          className={classNames(
            'cursor-pointer break-all',
            selected && 'font-extrabold'
          )}
        >
          {name}
        </label>
      </div>
      <button
        className="flex w-5 h-5 items-center justify-center"
        onClick={toggleSegmentDataVisible}
      >
        {segmentDataVisible ? (
          <ChevronUpIcon className="block w-4 h-4" />
        ) : (
          <ChevronDownIcon className="block w-4 h-4" />
        )}
      </button>

      {segmentDataVisible && (
        <div className="col-span-full mt-3">
          {data?.segment_data ? (
            <FilterPillsList
              className="flex-wrap"
              direction="horizontal"
              pills={data.segment_data.filters.map((filter) => ({
                // className: 'dark:!bg-gray-700',
                plainText: plainFilterText(data.segment_data.labels, filter),
                children: styledFilterText(data.segment_data.labels, filter),
                interactive: false
              }))}
            />
          ) : (
            'loading'
          )}
          {!!data && <SegmentAuthorship {...data} className="mt-3 text-xs" />}
          {!!data && (
            <div className="col-span-full mt-3 flex gap-x-4 gap-y-2 flex-wrap">
              <button
                className="flex gap-x-1 text-sm items-center hover:text-indigo-600 fill-current hover:fill-indigo-600"
                onClick={async () => {
                  expandSegment(data ?? (await fetchSegment()))
                }}
              >
                <EditSegmentIcon className="block h-4 w-4" />
                Edit
              </button>
              {/* <AppNavigationLink
                className="flex gap-x-1 text-sm items-center hover:text-indigo-600 fill-current hover:fill-indigo-600"
                path={rootRoute.path}
                search={(s) => s}
                state={
                  {
                    expandedSegment: data,
                    modal: 'delete'
                  } as SegmentExpandedLocationState
                }
                // onClick={async () => {
                //   expandSegment(data ?? (await fetchSegment()))
                // }}
              >
                <TrashIcon className="block h-4 w-4" />
                Delete
              </AppNavigationLink> */}
            </div>
          )}
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
  const [segmentDataVisibleIds, setSegmentDataVisibleIds] =
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

  const getToggleExpanded = useCallback(
    (id: number) => () =>
      setSegmentDataVisibleIds((current) =>
        current.includes(id)
          ? current.filter((i) => i !== id)
          : current.concat([id])
      ),
    []
  )

  const proposedSegmentFilter: Filter | null = selectedSegmentIds.length
    ? ['is', 'segment', selectedSegmentIds]
    : null

  const searchResults = data?.filter(getFilterSegmentsByNameInsensitive(search))

  const personalSegments = searchResults?.filter(
    (i) => i.type === SegmentType.personal
  )
  const siteSegments = searchResults?.filter((i) => i.type === SegmentType.site)

  const [upToPersonalSegment, setUpToPersonalSegment] = useState(4)
  const [upToSiteSegment, setUpToSiteSegment] = useState(4)

  useEffect(() => {
    setUpToPersonalSegment(4)
    setUpToSiteSegment(4)
  }, [data, search])

  return (
    <ModalWithRouting
      maxWidth="460px"
      className="p-6 min-h-fit text-gray-700 dark:text-gray-300"
    >
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-x-2">
          <h1 className="text-xl font-bold dark:text-gray-100">Segments</h1>
        </div>
        <SearchInput onSearch={(v) => setSearch(v)} />
      </div>
      <div className="my-4 border-b border-gray-300"></div>

      <div className="flex flex-col gap-y-2">
        {[
          {
            segments: personalSegments,
            title: 'Personal',
            sliceEnd: upToPersonalSegment,
            showMore: () => setUpToPersonalSegment((curr) => curr + 10)
          },
          {
            segments: siteSegments,
            title: 'Site',
            sliceEnd: upToSiteSegment,
            showMore: () => setUpToSiteSegment((curr) => curr + 10)
          }
        ]
          .filter((i) => !!i.segments?.length)
          .map(({ segments, title, sliceEnd, showMore }) => (
            <React.Fragment key={title}>
              <h2 className="mt-2 text-l font-bold dark:text-gray-100">
                {title}
              </h2>
              {segments!.slice(0, sliceEnd).map((item) => (
                <SegmentRow
                  segmentDataVisible={segmentDataVisibleIds.includes(item.id)}
                  toggleSegmentDataVisible={getToggleExpanded(item.id)}
                  key={item.id}
                  {...item}
                  toggleSelected={getToggleSelected(item.id)}
                  selected={selectedSegmentIds.includes(item.id)}
                />
              ))}
              {segments?.length && sliceEnd < segments.length && (
                <button
                  onClick={showMore}
                  className={classNames(
                    'self-center mt-1',
                    secondaryButtonClass
                  )}
                >
                  Show more
                </button>
              )}
            </React.Fragment>
          ))}
        {!personalSegments?.length && !siteSegments?.length && (
          <p>No segments found.</p>
        )}
      </div>

      <div className="mt-4">
        <ButtonsRow>
          <AppNavigationLink
            className={primaryNeutralButtonClass}
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
            Apply {selectedSegmentIds.length}{' '}
            {selectedSegmentIds.length === 1 ? 'segment' : 'segments'}
          </AppNavigationLink>
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
            Clear
          </AppNavigationLink>
        </ButtonsRow>
      </div>
    </ModalWithRouting>
  )
}
