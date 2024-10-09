import React from 'react'

export default function ChangeArrow({ change, metricName }: { change: number, metricName: string }) {
  if (change > 0) {
    const color = metricName === 'bounce_rate' ? 'text-red-400' : 'text-green-500'
    return (
      <span className="pl-2">
        <span className={color + ' font-bold'}>&uarr;</span>{' '}
      </span>
    )
  } else if (change < 0) {
    const color = metricName === 'bounce_rate' ? 'text-green-500' : 'text-red-400'
    return (
      <span className="pl-2">
        <span className={color + ' font-bold'}>&darr;</span>{' '}
      </span>
    )
  } else if (change === 0) {
    return <span className="pl-2">&#12336;</span>
  } else {
    return null
  }
}
