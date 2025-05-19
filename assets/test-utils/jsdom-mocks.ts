import { configMocks } from 'jsdom-testing-mocks'
import { act } from '@testing-library/react'

// as per jsdom-testing-mocks docs, this is needed to avoid having to wrap everything in act calls
configMocks({ act })
