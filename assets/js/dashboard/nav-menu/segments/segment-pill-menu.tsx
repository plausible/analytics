import React from 'react'
import classNames from 'classnames'
import { EyeIcon, Square2StackIcon } from '@heroicons/react/24/outline'
import {
  canExpandSegment,
  canSeeSaveAsSegmentAction,
  getNavigationToExpandSegment,
  SavedSegments
} from '../../filtering/segments'
import { plainFilterTextParts } from '../../util/filter-text'
import { SegmentAuthorship } from '../../segments/segment-authorship'
import { Role, useUserContext } from '../../user-context'
import { useRoutelessModalsContext } from '../../navigation/routeless-modals-context'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import { popover } from '../../components/popover'
import { PencilIcon, TrashIcon } from '../../components/icons'
import { MenuSeparator } from '../nav-menu-components'
import {
  SubmenuInPlace,
  SubmenuPanel,
  SubmenuRow,
  submenuIconClassName as iconClassName,
  useSubmenu
} from '../submenu'

const VIEW_FILTERS_LABEL = 'View filters'

const deleteClassName = classNames(
  popover.items.classNames.navigationLink,
  'gap-x-2 w-full text-left text-red-600 dark:text-red-400',
  'hover:bg-gray-100 focus-within:bg-gray-100 dark:hover:bg-gray-700 dark:focus-within:bg-gray-700'
)

const SegmentFilters = ({ segment }: { segment: SavedSegments[number] }) => (
  <>
    {segment.segment_data.filters.map((filter, index) => {
      const { subject, values } = plainFilterTextParts(
        segment.segment_data,
        filter
      )
      return (
        <div
          key={index}
          className={classNames(
            popover.items.classNames.staticRow,
            'flex flex-col'
          )}
        >
          <span className={popover.items.classNames.description}>
            {subject}
          </span>
          <span className="break-words">{values}</span>
        </div>
      )
    })}
  </>
)

export const SegmentPillMenu = ({
  segment,
  closeMenu
}: {
  segment: SavedSegments[number]
  closeMenu: () => void
}) => {
  const user = useUserContext()
  const { setModal } = useRoutelessModalsContext()
  const submenu = useSubmenu<'filters'>()
  const canEdit = canExpandSegment({ segment, user })
  const canDuplicate = canSeeSaveAsSegmentAction({ user })
  const filtersOpen = submenu.openKey === 'filters'

  if (filtersOpen && !submenu.besideMenu) {
    return (
      <SubmenuInPlace submenu={submenu} label={VIEW_FILTERS_LABEL}>
        <SegmentFilters segment={segment} />
      </SubmenuInPlace>
    )
  }

  return (
    <div
      className="flex flex-col gap-y-0.5"
      onMouseLeave={submenu.scheduleClose}
      onKeyDown={submenu.handleEscape}
    >
      <div
        className={classNames(
          popover.items.classNames.staticRow,
          'flex flex-col gap-y-0.5 font-semibold'
        )}
      >
        <span className="truncate" title={segment.name}>
          {segment.name}
        </span>
        <SegmentAuthorship
          className={popover.items.classNames.description}
          segment={segment}
          showOnlyPublicData={!user.loggedIn || user.role === Role.public}
        />
      </div>
      <MenuSeparator />
      <SubmenuRow
        label={VIEW_FILTERS_LABEL}
        Icon={EyeIcon}
        expanded={filtersOpen}
        submenuId={submenu.submenuId}
        onOpen={(anchor) => submenu.openWith('filters', anchor)}
      />
      {filtersOpen && (
        <SubmenuPanel submenu={submenu} label={VIEW_FILTERS_LABEL}>
          <SegmentFilters segment={segment} />
        </SubmenuPanel>
      )}
      {canEdit && (
        <AppNavigationLink
          className={popover.items.classNames.iconRow}
          onClick={closeMenu}
          onMouseEnter={submenu.scheduleClose}
          onFocus={submenu.scheduleClose}
          {...getNavigationToExpandSegment(segment)}
        >
          <PencilIcon className={iconClassName} />
          <span className={popover.items.classNames.label}>Edit segment</span>
        </AppNavigationLink>
      )}
      {canDuplicate && (
        <button
          type="button"
          className={popover.items.classNames.iconRow}
          onMouseEnter={submenu.scheduleClose}
          onFocus={submenu.scheduleClose}
          onClick={() => {
            closeMenu()
            setModal({ type: 'create-segment', segment })
          }}
        >
          <Square2StackIcon className={iconClassName} />
          <span className={popover.items.classNames.label}>
            Duplicate segment
          </span>
        </button>
      )}
      {canEdit && (
        <>
          <MenuSeparator />
          <button
            type="button"
            className={deleteClassName}
            onMouseEnter={submenu.scheduleClose}
            onFocus={submenu.scheduleClose}
            onClick={() => {
              closeMenu()
              setModal({ type: 'delete-segment', segment })
            }}
          >
            <TrashIcon className={iconClassName} />
            <span className={popover.items.classNames.label}>
              Delete segment
            </span>
          </button>
        </>
      )}
    </div>
  )
}
