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

export type TooltipSize = 'xs' | 'sm'

const tooltipSizes: Record<TooltipSize, string> = {
  xs: 'tooltip-xs',
  sm: 'tooltip-sm'
}

export type TooltipTheme = 'default' | 'darker'

const tooltipThemes: Record<TooltipTheme, string | null> = {
  default: null,
  darker: 'tooltip-theme-darker'
}

export const tooltipClassName = ({
  size = 'xs',
  theme = 'default',
  className
}: {
  size?: TooltipSize
  theme?: TooltipTheme
  className?: string
} = {}): string =>
  classNames('tooltip', tooltipSizes[size], tooltipThemes[theme], className)

export function Tooltip({
  children,
  info,
  className,
  size = 'xs',
  onClick,
  boundary,
  containerRef,
  interactive = false
}: {
  info: ReactNode
  children: ReactNode
  className?: string
  size?: TooltipSize
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
          offset: [0, 8]
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
      // lets the pointer move onto the tooltip before it hides
      hideTimeout.current = setTimeout(() => setVisible(false))
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
          size={size}
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
  size,
  containerRef,
  popperStyle,
  popperAttributes,
  setPopperElement,
  interactive,
  onMouseEnter,
  onMouseLeave,
  children
}: {
  size: TooltipSize
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
      className={tooltipClassName({
        size,
        className: classNames(
          'z-[99] [body:has(.modal.is-open)_&]:z-[1000]',
          interactive
            ? 'before:absolute before:inset-x-0 before:top-full before:h-2 [&[data-popper-placement^=bottom]]:before:top-auto [&[data-popper-placement^=bottom]]:before:bottom-full'
            : 'pointer-events-none'
        )
      })}
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
