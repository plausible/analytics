import React, { useMemo } from 'react'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  SavedSegmentPublic,
  SavedSegment,
  isListableSegment,
  getSearchToSetSegmentFilter,
  getSegmentAuthorship,
  getAttributionDateLabel
} from '../../filtering/segments'
import classNames from 'classnames'
import { SearchInput } from '../../components/search-input'
import { EllipsisHorizontalIcon } from '@heroicons/react/24/solid'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import { Role, useUserContext } from '../../user-context'
import { useSegmentsContext } from '../../filtering/segments-context'
import { useSearchableItems } from '../../hooks/use-searchable-items'
import { popover } from '../../components/popover'

const mutedRowClassName = classNames(
  popover.items.classNames.iconRow,
  'text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'
)

const INITIAL_SEGMENTS_SHOWN = 6

export const useListableSegments = (): {
  segments: (SavedSegment | SavedSegmentPublic)[]
  visible: boolean
} => {
  const site = useSiteContext()
  const user = useUserContext()
  const { segments, limitedToSegment } = useSegmentsContext()
  const { expandedSegment } = useDashboardStateContext()

  const listableSegments = useMemo(
    () =>
      segments.filter((segment) => isListableSegment({ segment, site, user })),
    [segments, site, user]
  )

  return {
    segments: listableSegments,
    visible:
      !expandedSegment && limitedToSegment === null && !!listableSegments.length
  }
}

export const SegmentsSubmenu = ({ closeList }: { closeList: () => void }) => {
  const user = useUserContext()
  const site = useSiteContext()
  const { segments } = useListableSegments()

  const isPublicListQuery = !user.loggedIn || user.role === Role.public

  const showAuthorship = site.siteSegmentsAvailable

  const {
    filteredData,
    showableData,
    showSearch,
    countOfMoreToShow,
    handleShowAll,
    handleClearSearch,
    handleSearchInput,
    searchRef,
    searching
  } = useSearchableItems({
    data: segments,
    maxItemsInitially: INITIAL_SEGMENTS_SHOWN,
    itemMatchesSearchValue: (segment, trimmedSearch) =>
      segment.name.toLowerCase().includes(trimmedSearch.toLowerCase())
  })

  return (
    <>
      {showSearch && (
        <SearchInput
          searchRef={searchRef}
          className="!max-w-none"
          onSearch={handleSearchInput}
        />
      )}

      <div className="flex flex-col gap-y-0.5 max-h-100 overflow-y-auto">
        {showableData.map((segment) => (
          <SegmentLink
            key={segment.id}
            segment={segment}
            showAuthorship={showAuthorship}
            showOnlyPublicData={isPublicListQuery}
            closeList={closeList}
          />
        ))}
        {countOfMoreToShow > 0 && (
          <button className={mutedRowClassName} onClick={handleShowAll}>
            <span className={popover.items.classNames.label}>
              {`Show ${countOfMoreToShow} more`}
            </span>
            <EllipsisHorizontalIcon className="block w-5 h-5 shrink-0" />
          </button>
        )}
      </div>
      {searching && !filteredData.length && (
        <button className={mutedRowClassName} onClick={handleClearSearch}>
          No segments found. Clear search to show all.
        </button>
      )}
    </>
  )
}

const SegmentLink = ({
  segment,
  showAuthorship,
  showOnlyPublicData,
  closeList
}: {
  segment: SavedSegment | SavedSegmentPublic
  showAuthorship: boolean
  showOnlyPublicData: boolean
  closeList: () => void
}) => {
  const { id, name } = segment
  const authorship = showAuthorship
    ? getSegmentAuthorship({ segment, showOnlyPublicData })
    : null
  const dateLabel = getAttributionDateLabel(segment)

  return (
    <AppNavigationLink
      className={popover.items.classNames.iconRow}
      onClick={closeList}
      search={getSearchToSetSegmentFilter({ id, name })}
    >
      <div className="flex flex-col gap-y-0.5 flex-1 min-w-0">
        <div className="truncate" title={name}>
          {name}
        </div>
        <div
          className={classNames(
            'flex items-baseline gap-x-1',
            popover.items.classNames.description
          )}
        >
          {!!authorship && (
            <span className="truncate min-w-0">{authorship}</span>
          )}
          <span className="whitespace-nowrap shrink-0">
            {authorship ? `• ${dateLabel}` : dateLabel}
          </span>
        </div>
      </div>
    </AppNavigationLink>
  )
}
