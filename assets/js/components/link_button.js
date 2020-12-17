import React from 'react'
import PropTypes from 'prop-types'
import { withRouter } from 'react-router-dom'

// from StackOverflow
// https://stackoverflow.com/a/49439893/

const LinkButton = (props) => {
  const {
    history,
    location,
    match,
    staticContext,
    to,
    onClick,
    // ⬆ filtering out props that `button` doesn’t know what to do with.
    ...rest
  } = props

  return (
    <button
      {...rest} // `children` is just another prop!
      onClick={(event) => {
        onClick && onClick(event)
        history.push(to)
      }}
    />
  )
}

// from Link in react-router-dom
const toType = PropTypes.oneOfType([
  PropTypes.string,
  PropTypes.object,
  PropTypes.func
]);

LinkButton.propTypes = {
  to: toType.isRequired,
  children: PropTypes.node.isRequired
}

export default withRouter(LinkButton)
