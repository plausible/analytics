import React, { useEffect } from 'react'
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
      isClosing: false
    }
    this.node = React.createRef()
    this.handleClickOutside = this.handleClickOutside.bind(this)
    this.handleResize = this.handleResize.bind(this)
    this.handleTouchStart = this.handleTouchStart.bind(this)
    this.handleTouchMove = this.handleTouchMove.bind(this)
    this.handleTouchEnd = this.handleTouchEnd.bind(this)
    this.touchStartY = null
    this.lastTouchY = null
  }

  componentDidMount() {
    document.body.style.overflow = 'hidden'
    document.body.style.height = '100vh'
    document.addEventListener('mousedown', this.handleClickOutside)
    window.addEventListener('resize', this.handleResize, false)
    this.handleResize()
  }

  componentWillUnmount() {
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
    this.setState({ viewport: window.innerWidth })
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
    styleObject.transform = `translateY(${this.state.dragOffset}px)`
    if (this.state.isClosing) {
      styleObject.transition = 'transform 150ms ease-out'
    } else {
      styleObject.transition =
        this.state.dragOffset > 0 ? 'none' : 'transform 150ms ease-out'
    }
    return styleObject
  }

  handleTouchStart(e) {
    if (this.state.viewport >= MD_WIDTH) return
    this.setState({ isClosing: false })
    const touch = e.touches[0]
    this.touchStartY = touch.clientY
    this.lastTouchY = touch.clientY
  }

  handleTouchMove(e) {
    if (this.state.viewport >= MD_WIDTH) return
    if (this.touchStartY === null) return
    const touch = e.touches[0]
    const deltaY = touch.clientY - this.touchStartY
    this.lastTouchY = touch.clientY
    if (deltaY <= 0) {
      this.setState({ dragOffset: 0 })
      return
    }
    e.preventDefault()
    this.setState({ dragOffset: deltaY })
  }

  handleTouchEnd() {
    if (this.state.viewport >= MD_WIDTH) return
    if (this.touchStartY === null || this.lastTouchY === null) {
      this.touchStartY = null
      this.lastTouchY = null
      return
    }
    const deltaY = this.lastTouchY - this.touchStartY
    this.touchStartY = null
    this.lastTouchY = null
    if (deltaY > 70) {
      this.setState(
        {
          dragOffset: Math.max(deltaY, window.innerHeight * 0.6),
          isClosing: true
        },
        () => {
          setTimeout(() => {
            this.props.onClose()
          }, 150)
        }
      )
      return
    }
    this.setState({ dragOffset: 0, isClosing: false })
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
                style={this.getStyle()}
                // eslint-disable-next-line jsx-a11y/no-noninteractive-tabindex
                tabIndex={0}
                onTouchStart={this.handleTouchStart}
                onTouchMove={this.handleTouchMove}
                onTouchEnd={this.handleTouchEnd}
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
