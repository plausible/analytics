/** @format */

import React, { useEffect, useState } from 'react'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import {
  formatSegmentIdAsLabelKey,
  getFilterSegmentsByNameInsensitive,
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

const linkClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.selectedOption,
  popover.items.classNames.hoverLink,
  popover.items.classNames.groupRoundedStartEnd
)

const initialSliceLength = 5

export const SearchableSegmentsSection = ({
  closeList
}: {
  closeList: () => void
}) => {
  const site = useSiteContext()
  const segmentsContext = useSegmentsContext()

  const { query, expandedSegment } = useQueryContext()
  const segmentFilter = query.filters.find(isSegmentFilter)
  const appliedSegmentIds = (segmentFilter ? segmentFilter[2] : []) as number[]
  const user = useUserContext()

  const isPublicListQuery = !user.loggedIn || user.role === Role.public

  const data = segmentsContext.segments.filter((segment) =>
    isListableSegment({ segment, site, user })
  )

  const [searchValue, setSearch] = useState<string>()
  const [showAll, setShowAll] = useState(false)

  const searching = !searchValue?.trim().length

  useEffect(() => {
    setShowAll(false)
  }, [searching])

  const filteredData = data?.filter(
    getFilterSegmentsByNameInsensitive(searchValue)
  )

  const showableSlice = showAll
    ? filteredData
    : filteredData?.slice(0, initialSliceLength)

  if (expandedSegment) {
    return null
  }

  return (
    <>
      {!!data?.length && (
        <>
          <MenuSeparator />
          <div className="flex items-center pt-2 px-4 pb-2">
            <div className="text-sm font-bold uppercase text-indigo-500 dark:text-indigo-400 mr-4">
              Segments
            </div>
            {data.length > initialSliceLength && (
              <SearchInput
                placeholderUnfocused="Press / to search"
                className="ml-auto w-full py-1 text-sm"
                onSearch={setSearch}
              />
            )}
          </div>

          {showableSlice!.map((segment) => {
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
                <SegmentLink
                  {...segment}
                  appliedSegmentIds={appliedSegmentIds}
                  closeList={closeList}
                />
              </Tooltip>
            )
          })}
          {!!filteredData?.length &&
            !!showableSlice?.length &&
            filteredData?.length > showableSlice?.length &&
            showAll === false && (
              <Tooltip className="group" info={null}>
                <AppNavigationLink
                  className={classNames(
                    linkClassName,
                    'font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
                  )}
                  search={(s) => s}
                  onClick={() => setShowAll(true)}
                >
                  {`Show ${filteredData.length - showableSlice.length} more`}
                  <EllipsisHorizontalIcon className="block w-5 h-5" />
                </AppNavigationLink>
              </Tooltip>
            )}
        </>
      )}
      {!!data?.length && searchValue && !showableSlice?.length && (
        <Tooltip className="group" info={null}>
          <div className={classNames(linkClassName)}>
            No segments found. Clear search to show all.
          </div>
        </Tooltip>
      )}
    </>
  )
}

const SegmentLink = ({
  id,
  name,
  appliedSegmentIds,
  closeList
}: Pick<SavedSegment, 'id' | 'name'> & {
  appliedSegmentIds: number[]
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
        const updatedSegmentIds = appliedSegmentIds.includes(id) ? [] : [id]
        if (!updatedSegmentIds.length) {
          return {
            ...search,
            filters: otherFilters,
            labels: cleanLabels(otherFilters, query.labels)
          }
        }

        const updatedFilters = [
          ['is', 'segment', updatedSegmentIds],
          ...otherFilters
        ]

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
