import React from "react";
import { createPortal } from "react-dom";
import { withRouter } from 'react-router-dom';

function SlideIn({show, children}) {
  const className = show ? "modal-enter-active" : "modal-enter"

  return <div className={className}>{children}</div>
}

class Modal extends React.Component {
  constructor(props) {
    super(props)
    this.node = React.createRef()
    this.handleClickOutside = this.handleClickOutside.bind(this)
    this.handleKeyup = this.handleKeyup.bind(this)
  }

  componentDidMount() {
    document.body.style.overflow = 'hidden';
    document.body.style.height = '100vh';
    document.addEventListener("mousedown", this.handleClickOutside);
    document.addEventListener("keyup", this.handleKeyup);
  }

  componentWillUnmount() {
    document.body.style.overflow = 'unset';
    document.body.style.height = 'unset';
    document.removeEventListener("mousedown", this.handleClickOutside);
    document.removeEventListener("keyup", this.handleKeyup);
  }

  handleClickOutside(e) {
    if (this.node.current.contains(e.target)) {
      return;
    }

    this.close()
  }

  handleKeyup(e) {
    if (e.code === 'Escape') {
      this.close()
    }
  }

  close() {
    this.props.history.push(`/${encodeURIComponent(this.props.site.domain)}${this.props.location.search}`)
  }

  render() {
    return createPortal(
      <div className="modal is-open" onClick={this.props.onClick}>
        <div className="modal__overlay">
          <button className="modal__close"></button>
          { !this.props.show &&
              <div className="modal__loader loading"><div></div></div>
          }

          <SlideIn show={this.props.show}>
            <div ref={this.node} className="modal__container">
              {this.props.children}
            </div>
          </SlideIn>

        </div>
      </div>,
      document.getElementById("modal_root"),
    );
  }
}


export default withRouter(Modal)
