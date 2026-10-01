import React, {
  ReactNode,
  useCallback,
  useEffect,
  useRef,
  useState
} from 'react'
import { createPortal } from 'react-dom'
import { Popover, Transition } from '@headlessui/react'
import { usePopper } from 'react-popper'
import {
  AppNavigationLink,
  AppNavigationTarget
} from '../navigation/use-app-navigate'
import { XMarkIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'
import { BlurMenuButtonOnEscape, popover } from '../components/popover'

type RenderMenu = (closeMenu: () => void) => ReactNode

export type FilterPillAction =
  | { type: 'link'; navigationTarget: AppNavigationTarget }
  | { type: 'menu'; renderMenu: RenderMenu }

export type FilterPillProps = {
  plainText: string
  action?: FilterPillAction
  onRemoveClick?: () => void
  children: ReactNode
}

const PillContent = ({ children }: { children?: ReactNode }) => (
  <span className="inline-block max-w-2xs md:max-w-xs truncate">
    {children}
  </span>
)

const contentBaseClassName =
  'flex w-full h-full items-center rounded-l-md pl-2.5'

const PillMenuPanel = ({
  open,
  buttonElement,
  children
}: {
  open: boolean
  buttonElement: HTMLButtonElement | null
  children: ReactNode
}) => {
  const [panelElement, setPanelElement] = useState<HTMLDivElement | null>(null)

  const { styles, attributes, update } = usePopper(
    buttonElement,
    panelElement,
    {
      placement: 'bottom-start',
      modifiers: [
        { name: 'offset', options: { offset: [-1, 8] } },
        { name: 'preventOverflow', options: { padding: 8 } }
      ]
    }
  )

  // the pill can move while the menu is closed, e.g. when the top bar changes
  useEffect(() => {
    if (open) {
      update?.()
    }
  }, [open, update])

  return createPortal(
    <div
      ref={setPanelElement}
      style={styles.popper}
      {...attributes.popper}
      className="z-20"
    >
      <Transition
        as="div"
        {...popover.transition.props}
        className="origin-top-left"
      >
        <Popover.Panel
          className={classNames(
            popover.panel.classNames.roundedSheet,
            'w-72 max-w-[calc(100vw-1rem)]'
          )}
        >
          {children}
        </Popover.Panel>
      </Transition>
    </div>,
    document.body
  )
}

const PillMenu = ({
  className,
  plainText,
  renderMenu,
  children
}: {
  className: string
  plainText: string
  renderMenu: RenderMenu
  children: ReactNode
}) => {
  const buttonRef = useRef<HTMLButtonElement | null>(null)
  const [buttonElement, setButtonElement] = useState<HTMLButtonElement | null>(
    null
  )
  const setButton = useCallback((element: HTMLButtonElement | null) => {
    buttonRef.current = element
    setButtonElement(element)
  }, [])

  return (
    <Popover className="flex h-full">
      {({ open, close }) => (
        <>
          <BlurMenuButtonOnEscape targetRef={buttonRef} />
          <Popover.Button
            ref={setButton}
            className={classNames(className, 'cursor-pointer')}
            title={plainText}
          >
            <PillContent>{children}</PillContent>
          </Popover.Button>
          <PillMenuPanel open={open} buttonElement={buttonElement}>
            {renderMenu(close)}
          </PillMenuPanel>
        </>
      )}
    </Popover>
  )
}

export function FilterPill({
  plainText,
  children,
  onRemoveClick,
  action
}: FilterPillProps) {
  const contentClassName = classNames(
    contentBaseClassName,
    !onRemoveClick && 'rounded-r-md pr-2.5'
  )

  return (
    <div className="flex h-8 rounded-md bg-white border border-gray-200 dark:border-gray-700 dark:bg-gray-800 text-gray-800 dark:text-gray-100 text-sm items-center">
      {action?.type === 'link' ? (
        <AppNavigationLink
          className={contentClassName}
          title={`Edit filter: ${plainText}`}
          {...action.navigationTarget}
        >
          <PillContent>{children}</PillContent>
        </AppNavigationLink>
      ) : action?.type === 'menu' ? (
        <PillMenu
          className={contentClassName}
          plainText={plainText}
          renderMenu={action.renderMenu}
        >
          {children}
        </PillMenu>
      ) : (
        <div className={contentClassName} title={plainText}>
          <PillContent>{children}</PillContent>
        </div>
      )}
      {!!onRemoveClick && (
        <button
          title={`Remove filter: ${plainText}`}
          className="flex items-center h-full rounded-r-md pl-1.5 pr-2.5 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 "
          onClick={onRemoveClick}
        >
          <XMarkIcon className="size-4" />
        </button>
      )}
    </div>
  )
}
