import React from 'react';

function barWidth(count, all) {
  let maxVal = all[0].count;

  for (const entry of all) {
    if (entry.count > maxVal) maxVal = entry.count
  }

  return count / maxVal * 100
}

export default function Bar({count, all, bg}) {
  const width = barWidth(count, all)

  return (
    <div className={bg} style={{width: width + '%', height: '30px'}}>
    </div>
  )
}
