import React from "react";
import { createPortal } from "react-dom";
import { withRouter } from 'react-router-dom';

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
    document.body.style.overflow = null;
    document.body.style.height = null;
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
          <div ref={this.node} className="modal__container dark:bg-gray-800">
            {this.props.children}
          </div>

        </div>
      </div>,
      document.getElementById("modal_root"),
    );
  }
}


export default withRouter(Modal)
