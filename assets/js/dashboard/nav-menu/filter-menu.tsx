import React, { useMemo, useRef } from 'react'
import { formattedFilters } from '../util/filters'
import { useSiteContext } from '../site-context'
import { filterRoute } from '../router'
import { FilterIcon } from '../components/icons'
import { Popover, Transition } from '@headlessui/react'
import { popover, BlurMenuButtonOnEscape } from '../components/popover'
import classNames from 'classnames'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import {
  SegmentsSubmenu,
  useListableSegments
} from './segments/segments-submenu'
import {
  FilterGroupKey,
  FilterMenuRow,
  FilterSubmenuRow,
  getFilterMenuRows,
  SEGMENTS_ROW
} from './filter-menu-rows'
import { MenuSeparator } from './nav-menu-components'
import {
  SubmenuInPlace,
  SubmenuPanel,
  SubmenuRow,
  submenuIconClassName as iconClassName,
  useSubmenu
} from './submenu'

const FilterMenuItems = ({ closeDropdown }: { closeDropdown: () => void }) => {
  const buttonRef = useRef<HTMLButtonElement>(null)

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Popover.Button
        ref={buttonRef}
        className={classNames(
          popover.toggleButton.classNames.rounded,
          popover.toggleButton.classNames.ghost
        )}
      >
        <FilterIcon className="block size-3.5" />
        <span className={popover.toggleButton.classNames.truncatedText}>
          Filter
        </span>
      </Popover.Button>
      <Transition
        as="div"
        {...popover.transition.props}
        className={classNames(
          popover.transition.classNames.fullwidth,
          'mt-2 md:left-auto md:w-56 md:origin-top-right'
        )}
      >
        <Popover.Panel
          className={popover.panel.classNames.roundedSheet}
          data-testid="filtermenu"
        >
          <FilterMenuPanelContent closeDropdown={closeDropdown} />
        </Popover.Panel>
      </Transition>
    </>
  )
}

const FilterMenuPanelContent = ({
  closeDropdown
}: {
  closeDropdown: () => void
}) => {
  const site = useSiteContext()
  const segments = useListableSegments()
  const submenu = useSubmenu<FilterGroupKey>()

  const rows = useMemo(() => {
    const filterRows = getFilterMenuRows(site)
    return segments.visible ? [SEGMENTS_ROW, ...filterRows] : filterRows
  }, [site, segments.visible])

  const openRow = useMemo(
    () =>
      rows.find(
        (row): row is FilterSubmenuRow =>
          row.kind !== 'item' && row.key === submenu.openKey
      ) ?? null,
    [rows, submenu.openKey]
  )

  const submenuBody = openRow && (
    <SubmenuBody row={openRow} closeDropdown={closeDropdown} />
  )

  if (openRow && !submenu.besideMenu) {
    return (
      <SubmenuInPlace
        submenu={submenu}
        label={openRow.label}
        testId="filtermenu-submenu"
      >
        {submenuBody}
      </SubmenuInPlace>
    )
  }

  return (
    <div
      className="flex flex-col gap-y-0.5"
      onMouseLeave={submenu.scheduleClose}
      onKeyDown={submenu.handleEscape}
    >
      {rows.map((row) => (
        <React.Fragment key={row.key}>
          {row.kind === 'item' ? (
            <ItemRow
              row={row}
              onPointerOrFocus={submenu.scheduleClose}
              closeDropdown={closeDropdown}
            />
          ) : (
            <>
              <SubmenuRow
                label={row.label}
                Icon={row.Icon}
                expanded={submenu.openKey === row.key}
                submenuId={submenu.submenuId}
                onOpen={(anchor) => submenu.openWith(row.key, anchor)}
              />
              {openRow?.key === row.key && (
                <SubmenuPanel
                  submenu={submenu}
                  label={openRow.label}
                  testId="filtermenu-submenu"
                >
                  {submenuBody}
                </SubmenuPanel>
              )}
            </>
          )}
          {row.kind === 'segments' && <MenuSeparator />}
        </React.Fragment>
      ))}
    </div>
  )
}

const ItemRow = ({
  row,
  onPointerOrFocus,
  closeDropdown
}: {
  row: Extract<FilterMenuRow, { kind: 'item' }>
  onPointerOrFocus: () => void
  closeDropdown: () => void
}) => (
  <AppNavigationLink
    className={popover.items.classNames.iconRow}
    onClick={closeDropdown}
    onMouseEnter={onPointerOrFocus}
    onFocus={onPointerOrFocus}
    path={filterRoute.path}
    params={{ field: row.dimension }}
    search={(s) => s}
  >
    <row.Icon className={iconClassName} />
    <span className={popover.items.classNames.label}>{row.label}</span>
  </AppNavigationLink>
)

const SubmenuBody = ({
  row,
  closeDropdown
}: {
  row: FilterSubmenuRow
  closeDropdown: () => void
}) => {
  if (row.kind === 'segments') {
    return <SegmentsSubmenu closeList={closeDropdown} />
  }
  return (
    <>
      {row.dimensions.map((dimension) => (
        <AppNavigationLink
          key={dimension}
          className={popover.items.classNames.iconRow}
          onClick={closeDropdown}
          path={filterRoute.path}
          params={{ field: dimension }}
          search={(s) => s}
        >
          <span className={popover.items.classNames.label}>
            {formattedFilters[dimension]}
          </span>
        </AppNavigationLink>
      ))}
    </>
  )
}

export const FilterMenu = () => (
  <Popover className="shrink-0 md:relative">
    {({ close }) => <FilterMenuItems closeDropdown={close} />}
  </Popover>
)
