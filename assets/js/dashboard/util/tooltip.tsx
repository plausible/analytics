import React, { CSSProperties, ReactNode, RefObject, useEffect, useRef, useState } from 'react'
import { usePopper } from 'react-popper'
import classNames from 'classnames'
import { createPortal } from 'react-dom'

export function Tooltip({
  children,
  info,
  className,
  onClick,
  boundary,
  containerRef,
  disableOverflow,
  delayed
}: {
  info: ReactNode
  children: ReactNode
  className?: string
  onClick?: () => void
  /** if provided, the tooltip is confined to the particular element */
  boundary?: HTMLElement | null
  /** if defined, the tooltip is rendered in a portal to this element */
  containerRef?: RefObject<HTMLElement>
  /** when true, completely disable Popper's preventOverflow behavior */
  disableOverflow?: boolean
  /** when true, apply fixed hover delays for show/hide */
  delayed?: boolean
}) {
  const [visible, setVisible] = useState(false)
  const showTimeoutRef = useRef<number | null>(null)

  const SHOW_DELAY_MS = 600
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
      ...(disableOverflow
        ? [
            {
              name: 'preventOverflow',
              enabled: false
            }
          ]
        : []),
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

  function handleMouseEnter() {
    const delay = delayed ? SHOW_DELAY_MS : 0
    if (delay > 0) {
      if (showTimeoutRef.current !== null) {
        window.clearTimeout(showTimeoutRef.current)
        showTimeoutRef.current = null
      }
      showTimeoutRef.current = window.setTimeout(() => {
        setVisible(true)
        showTimeoutRef.current = null
      }, delay)
    } else {
      setVisible(true)
    }
  }

  function handleMouseLeave() {
    if (showTimeoutRef.current !== null) {
      window.clearTimeout(showTimeoutRef.current)
      showTimeoutRef.current = null
    }
    setVisible(false)
  }

  useEffect(() => {
    return () => {
      if (showTimeoutRef.current !== null) {
        window.clearTimeout(showTimeoutRef.current)
        showTimeoutRef.current = null
      }
    }
  }, [])

  return (
    <div
      ref={setReferenceElement}
      className={classNames('relative', className)}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      onClick={onClick}
    >
      {children}
      {info && visible && (
        <TooltipMessage
          containerRef={containerRef}
          popperStyle={styles.popper}
          popperAttributes={attributes.popper}
          setPopperElement={setPopperElement}
          setArrowElement={setArrowElement}
          arrowStyle={styles.arrow}
          noWrap={Boolean(disableOverflow)}
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
  children,
  noWrap
}: {
  containerRef?: RefObject<HTMLElement>
  popperStyle: CSSProperties
  arrowStyle: CSSProperties
  popperAttributes?: Record<string, string>
  setPopperElement: (element: HTMLDivElement) => void
  setArrowElement: (element: HTMLDivElement) => void
  children: ReactNode
  noWrap?: boolean
}) {
  const [entering, setEntering] = useState(false)
  useEffect(() => {
    const id = requestAnimationFrame(() => setEntering(true))
    return () => cancelAnimationFrame(id)
  }, [])
  const messageElement = (
    <div
      ref={setPopperElement}
      style={popperStyle}
      {...popperAttributes}
      className="z-50"
      role="tooltip"
    >
      <div
        className={classNames(
          'py-1.5 px-2 rounded-md text-sm text-gray-100 font-medium bg-gray-800 dark:bg-gray-700',
          'transition-transform transition-opacity duration-200 ease-out origin-bottom',
          entering ? 'opacity-100 translate-y-0 scale-100' : 'opacity-0 translate-y-1 scale-95',
          { 'whitespace-nowrap': noWrap }
        )}
      >
        {children}
      </div>
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
