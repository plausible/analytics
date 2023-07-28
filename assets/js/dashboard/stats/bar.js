import React from 'react';

function barWidth(count, all, plot) {
  let maxVal = all[0][plot];

  for (const val of all) {
    if (val > maxVal) maxVal = val[plot]
  }

  return count / maxVal * 100
}

export default function Bar({count, all, bg, maxWidthDeduction, children, plot = "visitors"}) {
  const width = barWidth(count, all, plot)

  return (
    <div
      className="w-full relative"
      style={{maxWidth: `calc(100% - ${maxWidthDeduction})`}}
    >
      <div
        className={`absolute top-0 left-0 h-full ${bg || ''}`}
        style={{width: `${width}%`}}
      >
      </div>
      {children}
    </div>
  )
}
