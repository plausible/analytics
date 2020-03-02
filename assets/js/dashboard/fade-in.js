import React from 'react';

export default function FadeIn({show, children}) {
  const className = show ? "fade-enter-active" : "fade-enter"

  return <div className={className}>{children}</div>
}

