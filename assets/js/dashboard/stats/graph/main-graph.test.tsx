import React from 'react'
import { render } from '@testing-library/react'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import { Graph } from '../../components/graph'
import { MainGraph } from './main-graph'
import { MainGraphResponse } from './fetch-main-graph'

jest.mock('../../components/graph', () => ({ Graph: jest.fn(() => null) }))

const response: MainGraphResponse = {
  query: {
    metrics: ['visitors'],
    dimensions: ['time:day'],
    date_range: ['2026-09-01T00:00:00', '2026-09-03T23:59:59']
  },
  extraContext: { isRealtime: false, hasConversionGoalFilter: false },
  results: [{ dimensions: ['2026-09-02'], metrics: [21] }],
  comparison_results: [
    { dimensions: ['2026-08-02'], metrics: [6], change: null }
  ],
  meta: {
    time_labels: ['2026-09-01', '2026-09-02', '2026-09-03'],
    time_label_result_indices: [null, 0, null],
    comparison_time_labels: ['2026-08-01', '2026-08-02'],
    comparison_time_label_result_indices: [null, 0],
    empty_metrics: [0],
    present_index: 2,
    partial_time_labels: ['2026-09-03'],
    comparison_partial_time_labels: null
  }
}

function graphProps() {
  const calls = jest.mocked(Graph).mock.calls
  return calls[calls.length - 1][0]
}

test('smooths both zero-filled series and rescales without changing gaps or current segments', () => {
  const { rerender } = render(
    <MainGraph width={800} data={response} annotations={[]} />,
    { wrapper: TestContextProviders }
  )
  const original = graphProps()
  expect(original.data.map(({ values }) => values)).toEqual([
    [0, 0],
    [6, 21],
    [null, 0]
  ])
  expect(original.yMax).toBe(21)

  rerender(
    <MainGraph width={800} data={response} annotations={[]} smoothing="7" />
  )
  const smoothed = graphProps()
  expect(smoothed.data.map(({ values }) => values)).toEqual([
    [0, 0],
    [3, 10.5],
    [null, 7]
  ])
  expect(smoothed.yMax).toBe(10.5)
  expect(smoothed.settings).toEqual(original.settings)
  expect(smoothed.data.map(({ xLabel }) => xLabel)).toEqual(
    original.data.map(({ xLabel }) => xLabel)
  )

  rerender(
    <MainGraph width={800} data={response} annotations={[]} smoothing="none" />
  )
  expect(graphProps().data).toEqual(original.data)
  expect(response.results[0]?.metrics).toEqual([21])
})

test('does not apply a saved smoothing preference to the real-time graph', () => {
  render(
    <MainGraph
      width={800}
      data={{
        ...response,
        query: { ...response.query, dimensions: ['time:minute'] },
        extraContext: { ...response.extraContext, isRealtime: true }
      }}
      annotations={[]}
      smoothing="30"
    />,
    { wrapper: TestContextProviders }
  )
  expect(graphProps().data.map(({ values }) => values)).toEqual([
    [0, 0],
    [6, 21],
    [null, 0]
  ])
})
