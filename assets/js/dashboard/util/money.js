import React from 'react'

export function formatMoney(value) {
  return (<Money formatted={value} />)
}

export default function Money({ formatted }) {
  if (formatted) {
    return <span>{formatted.short}</span>
  } else {
    return "-"
  }
}
