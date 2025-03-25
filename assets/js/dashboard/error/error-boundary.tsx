import React, { ReactNode, ReactElement } from 'react'

type ErrorBoundaryProps = {
  children: ReactNode
  renderFallbackComponent: (props: { error?: unknown }) => ReactElement
}

type ErrorBoundaryState = { error: null | unknown }

export default class ErrorBoundary extends React.Component<
  ErrorBoundaryProps,
  ErrorBoundaryState
> {
  constructor(props: ErrorBoundaryProps) {
    super(props)
    this.state = { error: null }
  }

  static getDerivedStateFromError(error: unknown) {
    return { error }
  }

  render() {
    if (this.state.error) {
      return this.props.renderFallbackComponent({ error: this.state.error })
    }
    return this.props.children
  }
}
