import React from 'react'

export default function Money({ formatted }) {
  if (formatted) {
    return <span tooltip={formatted.long}>{formatted.short}</span>
  } else {
    return "-"
  }
}

