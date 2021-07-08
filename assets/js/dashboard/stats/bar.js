import React from 'react';

function barWidth(count, all) {
  let maxVal = all[0].count;

  for (const entry of all) {
    if (entry.count > maxVal) maxVal = entry.count
  }

  return count / maxVal * 100
}

export default function Bar({count, all, bg, maxWidthDeduction, children}) {
  const width = barWidth(count, all)

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
