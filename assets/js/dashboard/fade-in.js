import React from 'react'

export default function FadeIn({ className, show, children }) {
  return (
    <div
      className={`${className || ''} ${show ? 'fade-enter-active' : 'fade-enter'}`}
    >
      {children}
    </div>
  )
}
