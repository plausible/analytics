import React, {
  ComponentType,
  ReactNode,
  useCallback,
  useEffect,
  useId,
  useRef,
  useState
} from 'react'
import classNames from 'classnames'
import { usePopper } from 'react-popper'
import { ChevronLeftIcon, ChevronRightIcon } from '@heroicons/react/20/solid'
import { popover } from '../components/popover'
import { MenuSeparator } from './nav-menu-components'

export const submenuIconClassName = 'size-4 shrink-0'

const SUBMENU_CLOSE_DELAY_MS = 150

const isMdOrWider = () => window.matchMedia('(min-width: 768px)').matches

/**
 * `besideMenu` is measured when the submenu opens. If wide enough, the submenu
 * sits beside the menu; on small screens it replaces the menu.
 */
type OpenSubmenu<K extends string> = {
  key: K
  anchor: HTMLElement
  besideMenu: boolean
}

export function useSubmenu<K extends string>() {
  const submenuId = useId()
  const [openSubmenu, setOpenSubmenu] = useState<OpenSubmenu<K> | null>(null)
  const [submenuElement, setSubmenuElement] = useState<HTMLDivElement | null>(
    null
  )

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

  const openWith = useCallback(
    (key: K, anchor: HTMLElement) => {
      cancelScheduledClose()
      setOpenSubmenu({ key, anchor, besideMenu: isMdOrWider() })
    },
    [cancelScheduledClose]
  )

  const closeSubmenu = useCallback(() => setOpenSubmenu(null), [])

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

  return {
    submenuId,
    openKey: openSubmenu?.key ?? null,
    besideMenu: !!openSubmenu?.besideMenu,
    openWith,
    closeSubmenu,
    scheduleClose,
    handleEscape,
    panelProps: {
      ref: setSubmenuElement,
      style: styles.popper,
      ...attributes.popper,
      id: submenuId,
      onMouseEnter: cancelScheduledClose
    }
  }
}

type Submenu = ReturnType<typeof useSubmenu>

export const SubmenuRow = ({
  label,
  Icon,
  expanded,
  submenuId,
  onOpen
}: {
  label: string
  Icon: ComponentType<{ className?: string }>
  expanded: boolean
  submenuId: string
  onOpen: (anchor: HTMLElement) => void
}) => {
  const handleOpen = useCallback(
    (event: React.SyntheticEvent<HTMLButtonElement>) =>
      onOpen(event.currentTarget),
    [onOpen]
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
      <Icon className={submenuIconClassName} />
      <span className={popover.items.classNames.label}>{label}</span>
      <ChevronRightIcon className={submenuIconClassName} />
    </button>
  )
}

/** The submenu that sits beside the menu. */
export const SubmenuPanel = ({
  submenu,
  label,
  testId,
  children
}: {
  submenu: Pick<Submenu, 'panelProps'>
  label: string
  testId?: string
  children: ReactNode
}) => (
  <div
    {...submenu.panelProps}
    role="group"
    aria-label={label}
    data-testid={testId}
    className={classNames(popover.panel.classNames.roundedSheet, 'z-20 w-72')}
  >
    {children}
  </div>
)

/** The submenu that replaces the menu on small screens. */
export const SubmenuInPlace = ({
  submenu,
  label,
  testId,
  children
}: {
  submenu: Pick<Submenu, 'submenuId' | 'closeSubmenu' | 'handleEscape'>
  label: string
  testId?: string
  children: ReactNode
}) => (
  <div className="flex flex-col gap-y-0.5" onKeyDown={submenu.handleEscape}>
    <button
      className={popover.items.classNames.iconRow}
      onClick={submenu.closeSubmenu}
    >
      <ChevronLeftIcon className={submenuIconClassName} />
      <span className={popover.items.classNames.label}>{label}</span>
    </button>
    <MenuSeparator />
    <div
      className="flex flex-col gap-y-0.5"
      id={submenu.submenuId}
      role="group"
      aria-label={label}
      data-testid={testId}
    >
      {children}
    </div>
  </div>
)
