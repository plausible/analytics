import React, { useEffect } from 'react'
import Hammer from 'hammerjs'
import { createPortal } from 'react-dom'
import { isModifierPressed, isTyping, Keybind } from '../../keybinding'
import { rootRoute } from '../../router'
import { useAppNavigate } from '../../navigation/use-app-navigate'

// This corresponds to the 'md' breakpoint on TailwindCSS.
const MD_WIDTH = 768
// We assume that the dashboard is by default opened on a desktop. This is also a fall-back for when, for any reason, the width is not ascertained.
const DEFAULT_WIDTH = 1080

class Modal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      viewport: DEFAULT_WIDTH,
      dragOffset: 0,
      isDragging: false
    }
    this.node = React.createRef()
    this.canDrag = true
    this.hammerInstance = null
    this.handleClickOutside = this.handleClickOutside.bind(this)
    this.handleResize = this.handleResize.bind(this)
    this.handlePanStart = this.handlePanStart.bind(this)
    this.handlePanMove = this.handlePanMove.bind(this)
    this.handlePanEnd = this.handlePanEnd.bind(this)
    this.handlePanCancel = this.handlePanCancel.bind(this)
  }

  componentDidMount() {
    document.body.style.overflow = 'hidden'
    document.body.style.height = '100vh'
    document.addEventListener('mousedown', this.handleClickOutside)
    window.addEventListener('resize', this.handleResize, false)
    this.handleResize()
  }

  componentWillUnmount() {
    this.teardownHammer()
    document.body.style.overflow = null
    document.body.style.height = null
    document.removeEventListener('mousedown', this.handleClickOutside)
    window.removeEventListener('resize', this.handleResize, false)
  }

  handleClickOutside(e) {
    if (this.node.current.contains(e.target)) {
      return
    }

    this.props.onClose()
  }

  handleResize() {
    const viewport = window.innerWidth
    this.setState({ viewport })
    this.updateSwipeListener(viewport)
  }

  updateSwipeListener(viewport) {
    if (!this.node.current) return

    if (viewport < MD_WIDTH) {
      if (this.hammerInstance) return

      const hammer = new Hammer(this.node.current)
      hammer.get('pan').set({ direction: Hammer.DIRECTION_VERTICAL, threshold: 0 })
      hammer.on('panstart', this.handlePanStart)
      hammer.on('panmove', this.handlePanMove)
      hammer.on('panend', this.handlePanEnd)
      hammer.on('pancancel', this.handlePanCancel)
      this.hammerInstance = hammer
    } else {
      this.teardownHammer()
    }
  }

  handlePanStart(ev) {
    // Block drag if gesture starts inside a scrollable element (e.g., inner table)
    this.canDrag = !this.isFromScrollableTarget(ev.srcEvent?.target)
    if (!this.canDrag) {
      this.setState({ dragOffset: 0, isDragging: false })
    }
  }

  handlePanMove(ev) {
    if (!this.canDrag) return
    if (ev.direction === Hammer.DIRECTION_DOWN || ev.deltaY > 0) {
      this.setState({ dragOffset: ev.deltaY, isDragging: true })
    }
  }

  handlePanEnd(ev) {
    if (!this.canDrag) {
      this.setState({ dragOffset: 0, isDragging: false })
      return
    }

    const shouldClose = ev.deltaY > 80 || ev.velocityY > 0.35
    if (shouldClose) {
      this.props.onClose()
      return
    }

    // Snap back
    this.setState({ dragOffset: 0, isDragging: false })
  }

  handlePanCancel() {
    this.setState({ dragOffset: 0, isDragging: false })
    this.canDrag = true
  }

  getDragStyle() {
    const { dragOffset, isDragging } = this.state
    const clamped = Math.max(0, dragOffset)
    const opacity = Math.max(0, Math.min(1, 1 - clamped / 200))
    return {
      transform: `translateY(${clamped}px)`,
      opacity,
      transition: isDragging ? 'none' : 'transform 150ms ease-out, opacity 150ms ease-out'
    }
  }

  teardownHammer() {
    if (this.hammerInstance) {
      this.hammerInstance.off('panstart', this.handlePanStart)
      this.hammerInstance.off('panmove', this.handlePanMove)
      this.hammerInstance.off('panend', this.handlePanEnd)
      this.hammerInstance.off('pancancel', this.handlePanCancel)
      this.hammerInstance.destroy()
      this.hammerInstance = null
    }
  }

  isFromScrollableTarget(target) {
    if (!target || !this.node.current) return false

    let el = target
    while (el && el !== this.node.current) {
      const style = window.getComputedStyle(el)
      const isScrollable =
        (style.overflowY === 'auto' || style.overflowY === 'scroll') &&
        el.scrollHeight > el.clientHeight
      if (isScrollable) {
        return true
      }
      el = el.parentElement
    }
    return false
  }

  /**
   * @description
   * Decide whether to set max-width, and if so, to what.
   * If no max-width is available, set width instead to min-content such that we can rely on widths set on th.
   * On >md, we use the same behaviour as before: set width to 800 pixels.
   * Note that When a max-width comes from the parent component, we rely on that *always*.
   */
  getStyle() {
    const { maxWidth } = this.props
    const { viewport } = this.state
    const styleObject = {}
    if (maxWidth) {
      styleObject.maxWidth = maxWidth
    } else {
      styleObject.maxWidth = '880px'
    }
    return styleObject
  }

  render() {
    return createPortal(
      <>
        <Keybind
          keyboardKey="Escape"
          type="keyup"
          handler={this.props.onClose}
          targetRef="document"
          shouldIgnoreWhen={[isModifierPressed, isTyping]}
        />
        <div className="modal is-open" onClick={this.props.onClick}>
          <div className="modal__overlay">
            <div className="[--gap:1rem] sm:[--gap:2rem] md:[--gap:4rem] flex h-full w-full items-end md:items-start justify-center md:px-[var(--gap)] md:py-[var(--gap)] box-border">
              <div
                ref={this.node}
                className="max-h-[calc(100dvh_-_var(--gap)*2)] min-h-[66vh] md:min-h-120 w-full flex flex-col bg-white p-3 md:px-6 md:py-4 overflow-hidden box-border transition-[height] duration-200 ease-in shadow-2xl rounded-t-lg md:rounded-lg dark:bg-gray-900 focus:outline-hidden"
                style={{ ...this.getStyle(), ...this.getDragStyle() }}
                // eslint-disable-next-line jsx-a11y/no-noninteractive-tabindex
                tabIndex={0}
              >
                <FocusOnMount focusableRef={this.node} />
                {this.props.children}
              </div>
            </div>
          </div>
        </div>
      </>,
      document.getElementById('modal_root')
    )
  }
}

export default function ModalWithRouting(props) {
  const navigate = useAppNavigate()
  const onClose =
    props.onClose ??
    (() => navigate({ path: rootRoute.path, search: (s) => s }))
  return <Modal {...props} onClose={onClose} />
}

const FocusOnMount = ({ focusableRef }) => {
  useEffect(() => {
    if (typeof focusableRef.current?.focus === 'function') {
      focusableRef.current.focus()
    }
  }, [focusableRef])
  return null
}
