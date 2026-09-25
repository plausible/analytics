import React, {
  CSSProperties,
  ReactNode,
  RefObject,
  useEffect,
  useRef,
  useState
} from 'react'
import { usePopper } from 'react-popper'
import classNames from 'classnames'
import { createPortal } from 'react-dom'

const INTERACTIVE_HIDE_DELAY_MS = 150

export function Tooltip({
  children,
  info,
  className,
  onClick,
  boundary,
  containerRef,
  interactive = false
}: {
  info: ReactNode
  children: ReactNode
  className?: string
  onClick?: () => void
  /** if provided, the tooltip is confined to the particular element */
  boundary?: HTMLElement | null
  /** if defined, the tooltip is rendered in a portal to this element */
  containerRef?: RefObject<HTMLElement>
  /** if true, the tooltip stays open while hovered, so its content can be clicked */
  interactive?: boolean
}) {
  const [visible, setVisible] = useState(false)
  const hideTimeout = useRef<ReturnType<typeof setTimeout>>()
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

  useEffect(() => () => clearTimeout(hideTimeout.current), [])

  const show = () => {
    clearTimeout(hideTimeout.current)
    setVisible(true)
  }

  const hide = () => {
    if (interactive) {
      hideTimeout.current = setTimeout(
        () => setVisible(false),
        INTERACTIVE_HIDE_DELAY_MS
      )
    } else {
      setVisible(false)
    }
  }

  return (
    <div className={classNames('relative', className)}>
      <div
        ref={setReferenceElement}
        onMouseEnter={show}
        onMouseLeave={hide}
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
          interactive={interactive}
          onMouseEnter={interactive ? show : undefined}
          onMouseLeave={interactive ? hide : undefined}
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
  interactive,
  onMouseEnter,
  onMouseLeave,
  children
}: {
  containerRef?: RefObject<HTMLElement>
  popperStyle: CSSProperties
  popperAttributes?: Record<string, string>
  setPopperElement: (element: HTMLDivElement) => void
  interactive: boolean
  onMouseEnter?: () => void
  onMouseLeave?: () => void
  children: ReactNode
}) {
  const messageElement = (
    <div
      ref={setPopperElement}
      style={popperStyle}
      {...popperAttributes}
      className={classNames(
        'z-[99] [body:has(.modal.is-open)_&]:z-[1000] px-2 py-1 rounded-sm text-sm text-gray-100 font-medium bg-gray-800 dark:bg-gray-700',
        !interactive && 'pointer-events-none'
      )}
      role="tooltip"
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
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
