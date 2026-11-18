import { TextEncoder, TextDecoder } from 'util'
import { configMocks, mockViewport } from 'jsdom-testing-mocks'
import { act } from '@testing-library/react'

// as per jsdom-testing-mocks docs, this is needed to avoid having to wrap everything in act calls
configMocks({ act })

// jsdom has no window.matchMedia. Default every suite to a desktop viewport, and
// let suites that test responsive behaviour narrow it with mockViewportForTestGroup.
mockViewport({ width: '1024px', height: '768px' })

// jsdom has no TextEncoder/TextDecoder, which react-router v7 needs at import time.
Object.assign(global, { TextEncoder, TextDecoder })
