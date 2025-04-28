import React from 'react'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import {
  formatSegmentIdAsLabelKey,
  isSegmentFilter,
  SavedSegmentPublic,
  SavedSegment,
  SEGMENT_TYPE_LABELS,
  isListableSegment
} from '../../filtering/segments'
import { cleanLabels } from '../../util/filters'
import classNames from 'classnames'
import { Tooltip } from '../../util/tooltip'
import { SegmentAuthorship } from '../../segments/segment-authorship'
import { SearchInput } from '../../components/search-input'
import { EllipsisHorizontalIcon } from '@heroicons/react/24/solid'
import { popover } from '../../components/popover'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import { MenuSeparator } from '../nav-menu-components'
import { Role, useUserContext } from '../../user-context'
import { useSegmentsContext } from '../../filtering/segments-context'
import { useSearchableItems } from '../../hooks/use-searchable-items'

const linkClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.selectedOption,
  popover.items.classNames.hoverLink,
  popover.items.classNames.groupRoundedEnd
)

const INITIAL_SEGMENTS_SHOWN = 5

export const SearchableSegmentsSection = ({
  closeList
}: {
  closeList: () => void
}) => {
  const site = useSiteContext()
  const segmentsContext = useSegmentsContext()

  const { expandedSegment } = useQueryContext()
  const user = useUserContext()

  const isPublicListQuery = !user.loggedIn || user.role === Role.public

  const {
    data,
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
    data: segmentsContext.segments.filter((segment) =>
      isListableSegment({ segment, site, user })
    ),
    maxItemsInitially: INITIAL_SEGMENTS_SHOWN,
    itemMatchesSearchValue: (segment, trimmedSearch) =>
      segment.name.toLowerCase().includes(trimmedSearch.toLowerCase())
  })

  if (expandedSegment) {
    return null
  }

  if (!data.length) {
    return null
  }

  return (
    <>
      <MenuSeparator />
      <div className="flex items-center py-2 px-4">
        <div className="text-sm font-bold uppercase text-indigo-500 dark:text-indigo-400 mr-4">
          Segments
        </div>
        {showSearch && (
          <SearchInput
            searchRef={searchRef}
            placeholderUnfocused="Press / to search"
            className="ml-auto w-full py-1 text-sm"
            onSearch={handleSearchInput}
          />
        )}
      </div>

      <div className="max-h-[210px] overflow-y-scroll">
        {showableData.map((segment) => {
          return (
            <Tooltip
              className="group"
              key={segment.id}
              info={
                <div className="max-w-60">
                  <div className="break-all">{segment.name}</div>
                  <div className="font-normal text-xs">
                    {SEGMENT_TYPE_LABELS[segment.type]}
                  </div>

                  <SegmentAuthorship
                    className="font-normal text-xs"
                    {...(isPublicListQuery
                      ? {
                          showOnlyPublicData: true,
                          segment: segment as SavedSegmentPublic
                        }
                      : {
                          showOnlyPublicData: false,
                          segment: segment as SavedSegment
                        })}
                  />
                </div>
              }
            >
              <SegmentLink {...segment} closeList={closeList} />
            </Tooltip>
          )
        })}
        {countOfMoreToShow > 0 && (
          <Tooltip className="group" info={null}>
            <button
              className={classNames(
                linkClassName,
                'w-full text-left font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
              )}
              onClick={handleShowAll}
            >
              {`Show ${countOfMoreToShow} more`}
              <EllipsisHorizontalIcon className="block w-5 h-5" />
            </button>
          </Tooltip>
        )}
      </div>
      {searching && !filteredData.length && (
        <Tooltip className="group" info={null}>
          <button
            className={classNames(
              linkClassName,
              'w-full text-left font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
            )}
            onClick={handleClearSearch}
          >
            No segments found. Clear search to show all.
          </button>
        </Tooltip>
      )}
    </>
  )
}

const SegmentLink = ({
  id,
  name,
  closeList
}: Pick<SavedSegment, 'id' | 'name'> & {
  closeList: () => void
}) => {
  const { query } = useQueryContext()

  return (
    <AppNavigationLink
      className={linkClassName}
      key={id}
      onClick={closeList}
      search={(search) => {
        const otherFilters = query.filters.filter((f) => !isSegmentFilter(f))

        const updatedFilters = [['is', 'segment', [id]], ...otherFilters]

        return {
          ...search,
          filters: updatedFilters,
          labels: cleanLabels(updatedFilters, query.labels, 'segment', {
            [formatSegmentIdAsLabelKey(id)]: name
          })
        }
      }}
    >
      <div className="truncate">{name}</div>
    </AppNavigationLink>
  )
}
