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
  const [arrowElement, setArrowElement] = useState<HTMLDivElement | null>(null)

  const { styles, attributes } = usePopper(referenceElement, popperElement, {
    placement: 'top',
    modifiers: [
      { name: 'arrow', options: { element: arrowElement } },
      {
        name: 'offset',
        options: {
          offset: [0, 4]
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
          setArrowElement={setArrowElement}
          arrowStyle={styles.arrow}
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
  setArrowElement,
  arrowStyle,
  children
}: {
  containerRef?: RefObject<HTMLElement>
  popperStyle: CSSProperties
  arrowStyle: CSSProperties
  popperAttributes?: Record<string, string>
  setPopperElement: (element: HTMLDivElement) => void
  setArrowElement: (element: HTMLDivElement) => void
  children: ReactNode
}) {
  const messageElement = (
    <div
      ref={setPopperElement}
      style={popperStyle}
      {...popperAttributes}
      className="z-50 p-2 rounded text-sm text-gray-100 font-bold popper-tooltip"
      role="tooltip"
    >
      {children}
      <div
        ref={setArrowElement}
        style={arrowStyle}
        className="tooltip-arrow"
      ></div>
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
