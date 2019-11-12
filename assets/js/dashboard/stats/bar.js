import React from 'react';

function barWidth(count, all) {
  let maxVal = all[0].count;

  for (const entry of all) {
    if (entry.count > maxVal) maxVal = entry.count
  }

  return count / maxVal * 100
}

export default function Bar({count, all, color}) {
  color = color ? color : "blue"
  const width = barWidth(count, all)

  return (
    <div className="bar">
      <div className={`bar__fill bg-${color}`} style={{width: width + '%'}}></div>
    </div>
  )
}
