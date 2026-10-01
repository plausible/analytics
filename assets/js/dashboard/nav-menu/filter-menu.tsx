import React, {
  useCallback,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState
} from 'react'
import { formattedFilters } from '../util/filters'
import { useSiteContext } from '../site-context'
import { filterRoute } from '../router'
import { FilterIcon } from '../components/icons'
import { Popover, Transition } from '@headlessui/react'
import { ChevronLeftIcon, ChevronRightIcon } from '@heroicons/react/20/solid'
import { usePopper } from 'react-popper'
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

const iconClassName = 'size-4 shrink-0'

const SUBMENU_CLOSE_DELAY_MS = 150

const isMdOrWider = () => window.matchMedia('(min-width: 768px)').matches

/**
 * `besideMenu` is measured when the submenu opens. If wide enough, the submenu
 * sits beside the menu; on small screens it replaces the menu.
 */
type OpenSubmenu = {
  key: FilterGroupKey
  anchor: HTMLElement
  besideMenu: boolean
}

const FilterMenuItems = ({
  open,
  closeDropdown
}: {
  open: boolean
  closeDropdown: () => void
}) => {
  const site = useSiteContext()
  const segments = useListableSegments()
  const buttonRef = useRef<HTMLButtonElement>(null)
  const submenuId = useId()

  const rows = useMemo(() => {
    const filterRows = getFilterMenuRows(site)
    return segments.visible ? [SEGMENTS_ROW, ...filterRows] : filterRows
  }, [site, segments.visible])

  const [openSubmenu, setOpenSubmenu] = useState<OpenSubmenu | null>(null)
  const [submenuElement, setSubmenuElement] = useState<HTMLDivElement | null>(
    null
  )
  const openRow = useMemo(
    () =>
      rows.find(
        (row): row is FilterSubmenuRow =>
          row.kind !== 'item' && row.key === openSubmenu?.key
      ) ?? null,
    [rows, openSubmenu]
  )
  const besideMenu = !!openSubmenu?.besideMenu

  const closeTimeout = useRef<ReturnType<typeof setTimeout>>()
  const cancelScheduledClose = useCallback(() => {
    if (closeTimeout.current) {
      clearTimeout(closeTimeout.current)
      closeTimeout.current = undefined
    }
  }, [])
  const scheduleClose = useCallback(() => {
    cancelScheduledClose()
    closeTimeout.current = setTimeout(
      () => setOpenSubmenu(null),
      SUBMENU_CLOSE_DELAY_MS
    )
  }, [cancelScheduledClose])
  useEffect(() => cancelScheduledClose, [cancelScheduledClose])

  useEffect(() => {
    if (!open) {
      setOpenSubmenu(null)
    }
  }, [open])

  const openWith = useCallback(
    (key: FilterGroupKey, anchor: HTMLElement) => {
      cancelScheduledClose()
      setOpenSubmenu({ key, anchor, besideMenu: isMdOrWider() })
    },
    [cancelScheduledClose]
  )

  const closeSubmenuAndRefocus = useCallback(() => {
    cancelScheduledClose()
    openSubmenu?.anchor.focus()
    setOpenSubmenu(null)
  }, [cancelScheduledClose, openSubmenu])

  /**
   * The submenu opens on the right side by default, and flips to the
   * left when the viewport doesn't have enough room.
   */
  const { styles, attributes } = usePopper(
    openSubmenu?.anchor ?? null,
    submenuElement,
    {
      placement: 'right-start',
      modifiers: [
        { name: 'offset', options: { offset: [-4, 0] } },
        { name: 'flip', options: { fallbackPlacements: ['left-start'] } },
        { name: 'preventOverflow', options: { padding: 8 } }
      ]
    }
  )

  const handleEscape = useCallback(
    (event: React.KeyboardEvent) => {
      if (event.key === 'Escape' && openSubmenu) {
        closeSubmenuAndRefocus()
        event.stopPropagation()
      }
    },
    [closeSubmenuAndRefocus, openSubmenu]
  )

  const submenuBody = openRow && (
    <SubmenuBody row={openRow} closeDropdown={closeDropdown} />
  )

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
          {openRow && !besideMenu ? (
            <div className="flex flex-col gap-y-0.5" onKeyDown={handleEscape}>
              <button
                className={popover.items.classNames.iconRow}
                onClick={() => setOpenSubmenu(null)}
              >
                <ChevronLeftIcon className={iconClassName} />
                <span className={popover.items.classNames.label}>
                  {openRow.label}
                </span>
              </button>
              <MenuSeparator />
              <div
                className="flex flex-col gap-y-0.5"
                id={submenuId}
                role="group"
                aria-label={openRow.label}
                data-testid="filtermenu-submenu"
              >
                {submenuBody}
              </div>
            </div>
          ) : (
            <div
              className="flex flex-col gap-y-0.5"
              onMouseLeave={scheduleClose}
              onKeyDown={handleEscape}
            >
              {rows.map((row) => (
                <React.Fragment key={row.key}>
                  {row.kind === 'item' ? (
                    <ItemRow
                      row={row}
                      onPointerOrFocus={scheduleClose}
                      closeDropdown={closeDropdown}
                    />
                  ) : (
                    <>
                      <SubmenuRow
                        row={row}
                        expanded={openSubmenu?.key === row.key}
                        submenuId={submenuId}
                        onOpen={openWith}
                      />
                      {openRow?.key === row.key && (
                        <div
                          ref={setSubmenuElement}
                          style={styles.popper}
                          {...attributes.popper}
                          id={submenuId}
                          role="group"
                          aria-label={openRow.label}
                          data-testid="filtermenu-submenu"
                          className={classNames(
                            popover.panel.classNames.roundedSheet,
                            'z-20 w-72'
                          )}
                          onMouseEnter={cancelScheduledClose}
                        >
                          {submenuBody}
                        </div>
                      )}
                    </>
                  )}
                  {row.kind === 'segments' && <MenuSeparator />}
                </React.Fragment>
              ))}
            </div>
          )}
        </Popover.Panel>
      </Transition>
    </>
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

const SubmenuRow = ({
  row,
  expanded,
  submenuId,
  onOpen
}: {
  row: FilterSubmenuRow
  expanded: boolean
  submenuId: string
  onOpen: (key: FilterGroupKey, anchor: HTMLElement) => void
}) => {
  const handleOpen = useCallback(
    (event: React.SyntheticEvent<HTMLButtonElement>) =>
      onOpen(row.key, event.currentTarget),
    [onOpen, row.key]
  )

  const handleHoverOrFocus = useCallback(
    (event: React.SyntheticEvent<HTMLButtonElement>) => {
      if (isMdOrWider()) {
        handleOpen(event)
      }
    },
    [handleOpen]
  )

  return (
    <button
      className={classNames(
        popover.items.classNames.iconRow,
        popover.items.classNames.selectedOption
      )}
      data-selected={expanded}
      aria-expanded={expanded}
      aria-controls={expanded ? submenuId : undefined}
      onClick={handleOpen}
      onMouseEnter={handleHoverOrFocus}
      onFocus={handleHoverOrFocus}
    >
      <row.Icon className={iconClassName} />
      <span className={popover.items.classNames.label}>{row.label}</span>
      <ChevronRightIcon className={iconClassName} />
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
    {({ open, close }) => <FilterMenuItems open={open} closeDropdown={close} />}
  </Popover>
)
