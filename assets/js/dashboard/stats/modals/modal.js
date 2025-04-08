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
      viewport: DEFAULT_WIDTH
    }
    this.node = React.createRef()
    this.handleClickOutside = this.handleClickOutside.bind(this)
    this.handleResize = this.handleResize.bind(this)
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
      styleObject.width = viewport <= MD_WIDTH ? 'min-content' : '860px'
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
            <button className="modal__close"></button>
            <div
              ref={this.node}
              className="modal__container dark:bg-gray-800 focus:outline-none"
              style={this.getStyle()}
              // eslint-disable-next-line jsx-a11y/no-noninteractive-tabindex
              tabIndex={0}
            >
              <FocusOnMount focusableRef={this.node} />
              {this.props.children}
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
