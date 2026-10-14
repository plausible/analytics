import React, { useMemo, useRef } from 'react'
import { EVENT_PROPS_PREFIX, formattedFilters } from '../util/filters'
import { useSiteContext } from '../site-context'
import { FilterIcon } from '../components/icons'
import { Popover, Transition } from '@headlessui/react'
import { PlusIcon } from '@heroicons/react/24/outline'
import { Tooltip } from '../util/tooltip'
import { popover, BlurMenuButtonOnEscape } from '../components/popover'
import classNames from 'classnames'
import { useFilterEditorContext } from '../filtering/filter-editor-context'
import { PropertyKeyPicker } from './property-key-picker'
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

const FilterMenuItems = ({
  open,
  closeDropdown,
  compact
}: {
  open: boolean
  closeDropdown: () => void
  compact: boolean
}) => {
  const buttonRef = useRef<HTMLButtonElement>(null)

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      {compact ? (
        <Tooltip
          info={open ? null : 'Add filter'}
          containerRef={{ current: document.body }}
        >
          <Popover.Button
            ref={buttonRef}
            aria-label="Add filter"
            className={classNames(
              popover.toggleButton.classNames.rounded,
              popover.toggleButton.classNames.ghost,
              'justify-center relative z-20'
            )}
          >
            <PlusIcon className="block size-4" />
          </Popover.Button>
        </Tooltip>
      ) : (
        <Popover.Button
          ref={buttonRef}
          className={classNames(
            popover.toggleButton.classNames.rounded,
            popover.toggleButton.classNames.ghost,
            'relative z-20'
          )}
        >
          <FilterIcon className="block size-3.5" />
          <span className={popover.toggleButton.classNames.truncatedText}>
            Filter
          </span>
        </Popover.Button>
      )}
      <Transition
        as="div"
        {...popover.transition.props}
        className={classNames(
          popover.transition.classNames.fullwidth,
          'mt-2 md:w-56',
          compact
            ? 'md:right-auto md:origin-top-left'
            : 'md:left-auto md:origin-top-right'
        )}
      >
        <div className="fixed top-0 left-0 w-full h-full"></div>
        <Popover.Panel
          className={classNames(
            popover.panel.classNames.roundedSheet,
            'relative'
          )}
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
    <div className="flex flex-col gap-y-0.5" onKeyDown={submenu.handleEscape}>
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
}) => {
  const { add } = useFilterEditorContext()
  return (
    <button
      type="button"
      className={popover.items.classNames.iconRow}
      onClick={() => {
        closeDropdown()
        add(row.dimension)
      }}
      onMouseEnter={onPointerOrFocus}
      onFocus={onPointerOrFocus}
    >
      <row.Icon className={iconClassName} />
      <span className={popover.items.classNames.label}>{row.label}</span>
    </button>
  )
}

const SubmenuBody = ({
  row,
  closeDropdown
}: {
  row: FilterSubmenuRow
  closeDropdown: () => void
}) => {
  const { add } = useFilterEditorContext()
  if (row.kind === 'segments') {
    return <SegmentsSubmenu closeList={closeDropdown} />
  }
  if (row.kind === 'properties') {
    return (
      <PropertyKeyPicker
        onSelect={(propKey) => {
          closeDropdown()
          add(`${EVENT_PROPS_PREFIX}${propKey}`)
        }}
      />
    )
  }
  return (
    <>
      {row.dimensions.map((dimension) => (
        <button
          key={dimension}
          type="button"
          className={popover.items.classNames.iconRow}
          onClick={() => {
            closeDropdown()
            add(dimension)
          }}
        >
          <span className={popover.items.classNames.label}>
            {formattedFilters[dimension]}
          </span>
        </button>
      ))}
    </>
  )
}

export const FilterMenu = ({ compact = false }: { compact?: boolean }) => (
  <Popover className="shrink-0 md:relative">
    {({ open, close }) => (
      <FilterMenuItems open={open} closeDropdown={close} compact={compact} />
    )}
  </Popover>
)
