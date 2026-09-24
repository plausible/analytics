import React, { useEffect } from 'react'
import { createPortal } from 'react-dom'
import classNames from 'classnames'
import { isModifierPressed, isTyping, Keybind } from '../../keybinding'
import { rootRoute } from '../../router'
import { useAppNavigate } from '../../navigation/use-app-navigate'

class Modal extends React.Component {
  constructor(props) {
    super(props)
    this.node = React.createRef()
    this.handleClickOutside = this.handleClickOutside.bind(this)
  }

  componentDidMount() {
    document.body.style.overflow = 'hidden'
    document.body.style.height = '100vh'
    document.addEventListener('mousedown', this.handleClickOutside)
  }
  componentWillUnmount() {
    document.body.style.overflow = null
    document.body.style.height = null
    document.removeEventListener('mousedown', this.handleClickOutside)
  }
  handleClickOutside(e) {
    if (this.node.current.contains(e.target)) {
      return
    }
    this.props.onClose()
  }

  render() {
    // `grow` lets the panel grow with its content (the overlay handles
    // scroll). Leave it off when a child uses `flex-1 overflow-auto` for
    // its own inner scroll region (e.g. `BreakdownTable`).
    const grow = this.props.grow === true

    const panelClass = classNames(
      'w-full flex flex-col bg-white p-3 md:px-6 md:py-4 box-border shadow-2xl rounded-lg dark:bg-gray-900 focus:outline-hidden',
      {
        'max-h-[calc(100dvh_-_var(--gap)*2)] transition-[height] duration-200 ease-in':
          !grow
      }
    )

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
            <div className="[--gap:1rem] sm:[--gap:2rem] md:[--gap:3.2rem] flex h-full w-full items-start justify-center p-[var(--gap)] box-border">
              <div
                ref={this.node}
                className={panelClass}
                style={{ maxWidth: this.props.maxWidth || '880px' }}
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
