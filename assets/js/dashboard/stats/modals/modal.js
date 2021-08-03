import React from "react";
import { createPortal } from "react-dom";
import { withRouter } from 'react-router-dom';

// This corresponds to the iPad width in portrait mode. This does NOT cater to iPad Pro, which in this case is fine to be treated as a full desktop screen, as is the landscape mode for a regular iPad.
const MAX_TABLET_WIDTH = 800;
// We assume that the dashboard is by default opened on a desktop. This is also a fall-back for when, for any reason, the width is not ascertained.
const DEFAULT_WIDTH = 1080;


class Modal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      viewport: DEFAULT_WIDTH,
    }
    this.node = React.createRef()
    this.handleClickOutside = this.handleClickOutside.bind(this)
    this.handleKeyup = this.handleKeyup.bind(this)
    this.handleResize = this.handleResize.bind(this)
  }

  componentDidMount() {
    document.body.style.overflow = 'hidden';
    document.body.style.height = '100vh';
    document.addEventListener("mousedown", this.handleClickOutside);
    document.addEventListener("keyup", this.handleKeyup);
    window.addEventListener('resize', this.handleResize, false);
    this.handleResize();
  }

  componentWillUnmount() {
    document.body.style.overflow = null;
    document.body.style.height = null;
    document.removeEventListener("mousedown", this.handleClickOutside);
    document.removeEventListener("keyup", this.handleKeyup);
    window.removeEventListener('resize', this.handleResize, false);
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

  handleResize() {
    this.setState({ viewport: window.innerWidth });
  }

  close() {
    this.props.history.push(`/${encodeURIComponent(this.props.site.domain)}${this.props.location.search}`)
  }

  /**
   * @description
   * Decide whether to set max-width, and if so, to what.
   * If no max-width is available, set width instead to max-content.
   * On >tablet, we use the same behaviour as before: limit max-width to 800 pixels.
   * * Note that When a max-width comes from the parent component, we rely on that always.
   */
  getStyle() {
    const { maxWidth } = this.props;
    const { viewport } = this.state;
    const styleObject = {};
    if (maxWidth) {
      styleObject.maxWidth = maxWidth;
    } else {
      styleObject.width = viewport > MAX_TABLET_WIDTH ? "800px" : "max-content";
    }
    return styleObject;
  }

  render() {
    return createPortal(
      <div className="modal is-open" onClick={this.props.onClick}>
        <div className="modal__overlay">
          <button className="modal__close"></button>
          <div
            ref={this.node}
            className="modal__container dark:bg-gray-800"
            style={this.getStyle()}
          >
            {this.props.children}
          </div>

        </div>
      </div>,
      document.getElementById("modal_root"),
    );
  }
}


export default withRouter(Modal)
