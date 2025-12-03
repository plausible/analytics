import React, { CSSProperties, ReactNode, RefObject, useState } from 'react'
import { usePopper } from 'react-popper'
import classNames from 'classnames'
import { createPortal } from 'react-dom'

export function Tooltip({
  children,
  info,
  className,
  onClick,
  boundary,
  containerRef
}: {
  info: ReactNode
  children: ReactNode
  className?: string
  onClick?: () => void
  /** if provided, the tooltip is confined to the particular element */
  boundary?: HTMLElement | null
  /** if defined, the tooltip is rendered in a portal to this element */
  containerRef?: RefObject<HTMLElement>
}) {
  const [visible, setVisible] = useState(false)
  const [referenceElement, setReferenceElement] =
    useState<HTMLDivElement | null>(null)
  const [popperElement, setPopperElement] = useState<HTMLDivElement | null>(
    null
  )

  const { styles, attributes } = usePopper(referenceElement, popperElement, {
    placement: 'top',
    modifiers: [
      {
        name: 'offset',
        options: {
          offset: [0, 6]
        }
      },
      ...(boundary
        ? [
            {
              name: 'preventOverflow',
              options: {
                boundary: boundary
              }
            }
          ]
        : [])
    ]
  })

  return (
    <div className={classNames('relative', className)}>
      <div
        ref={setReferenceElement}
        onMouseEnter={() => setVisible(true)}
        onMouseLeave={() => setVisible(false)}
        onClick={onClick}
      >
        {children}
      </div>
      {info && visible && (
        <TooltipMessage
          containerRef={containerRef}
          popperStyle={styles.popper}
          popperAttributes={attributes.popper}
          setPopperElement={setPopperElement}
        >
          {info}
        </TooltipMessage>
      )}
    </div>
  )
}

function TooltipMessage({
  containerRef,
  popperStyle,
  popperAttributes,
  setPopperElement,
  children
}: {
  containerRef?: RefObject<HTMLElement>
  popperStyle: CSSProperties
  popperAttributes?: Record<string, string>
  setPopperElement: (element: HTMLDivElement) => void
  children: ReactNode
}) {
  const messageElement = (
    <div
      ref={setPopperElement}
      style={popperStyle}
      {...popperAttributes}
      className="z-[999] px-2 py-1 rounded-sm text-sm text-gray-100 font-medium bg-gray-800 dark:bg-gray-700"
      role="tooltip"
    >
      {children}
    </div>
  )
  if (containerRef) {
    if (containerRef.current) {
      return createPortal(messageElement, containerRef.current)
    } else {
      return null
    }
  }

  return messageElement
}
