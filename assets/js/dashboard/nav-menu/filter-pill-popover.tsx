import React, { ReactNode, useEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import { Transition } from '@headlessui/react'
import { usePopper } from 'react-popper'
import classNames from 'classnames'
import { popover } from '../components/popover'

/**
 * Headless UI popovers can't be opened from code, which the filter editor
 * needs when a filter is added from the filter menu.
 */
export const FilterPillPopover = ({
  anchorElement,
  containerElement,
  onClose,
  className,
  children
}: {
  anchorElement: HTMLElement | null
  /** Pointer and focus events inside this element don't close the popover */
  containerElement: HTMLElement | null
  onClose: (options: { refocus: boolean }) => void
  className?: string
  children: ReactNode
}) => {
  const [panelElement, setPanelElement] = useState<HTMLDivElement | null>(null)

  const { styles, attributes } = usePopper(anchorElement, panelElement, {
    placement: 'bottom-start',
    modifiers: [
      { name: 'offset', options: { offset: [-1, 8] } },
      { name: 'preventOverflow', options: { padding: 8 } }
    ]
  })

  useEffect(() => {
    anchorElement?.scrollIntoView?.({ block: 'nearest', inline: 'nearest' })
  }, [anchorElement])

  useEffect(() => {
    const isInside = (target: EventTarget | null) =>
      target instanceof Node &&
      (!!panelElement?.contains(target) || !!containerElement?.contains(target))

    const onPointerDown = (event: PointerEvent) => {
      if (!isInside(event.target)) {
        onClose({ refocus: false })
      }
    }
    const onFocusIn = (event: FocusEvent) => {
      if (!isInside(event.target)) {
        onClose({ refocus: false })
      }
    }
    document.addEventListener('pointerdown', onPointerDown)
    document.addEventListener('focusin', onFocusIn)
    return () => {
      document.removeEventListener('pointerdown', onPointerDown)
      document.removeEventListener('focusin', onFocusIn)
    }
  }, [panelElement, containerElement, onClose])

  return createPortal(
    <div
      ref={setPanelElement}
      style={styles.popper}
      {...attributes.popper}
      className="z-20"
      onKeyDown={(event) => {
        if (event.key === 'Escape') {
          event.stopPropagation()
        }
      }}
      // the dashboard clears all filters on Escape keyup
      onKeyUp={(event) => {
        if (event.key === 'Escape') {
          event.stopPropagation()
          onClose({ refocus: true })
        }
      }}
    >
      <Transition
        as="div"
        appear
        show
        {...popover.transition.props}
        className="origin-top-left"
      >
        <div
          className={classNames(
            popover.panel.classNames.roundedSheet,
            'max-w-[calc(100vw-1rem)]',
            className
          )}
        >
          {children}
        </div>
      </Transition>
    </div>,
    document.body
  )
}
