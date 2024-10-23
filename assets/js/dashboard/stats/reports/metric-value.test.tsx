/** @format */

import React from 'react'
import {
  render as libraryRender,
  screen,
  fireEvent,
  waitFor
} from '@testing-library/react'
import MetricValue from './metric-value'
import SiteContextProvider, { PlausibleSite } from '../../site-context'

jest.mock('@heroicons/react/24/solid', () => ({
  ArrowUpRightIcon: () => <>↑</>,
  ArrowDownRightIcon: () => <>↓</>
}))

const REVENUE = { long: '$1,659.50', short: '$1.7K' }

describe('single value', () => {
  it('renders small value', async () => {
    await renderWithTooltip(<MetricValue {...valueProps('visitors', 10)} />)

    expect(screen.getByTestId('metric-value')).toHaveTextContent('10')
    expect(screen.getByRole('tooltip')).toHaveTextContent('10')
  })

  it('renders large value', async () => {
    await renderWithTooltip(<MetricValue {...valueProps('visitors', 12345)} />)

    expect(screen.getByTestId('metric-value')).toHaveTextContent('12.3k')
    expect(screen.getByRole('tooltip')).toHaveTextContent('12,345')
  })

  it('renders percentages', async () => {
    await renderWithTooltip(<MetricValue {...valueProps('bounce_rate', 5.3)} />)

    expect(screen.getByTestId('metric-value')).toHaveTextContent('5.3%')
    expect(screen.getByRole('tooltip')).toHaveTextContent('5.3%')
  })

  it('renders durations', async () => {
    await renderWithTooltip(
      <MetricValue {...valueProps('visit_duration', 60)} />
    )

    expect(screen.getByTestId('metric-value')).toHaveTextContent('1m 00s')
    expect(screen.getByRole('tooltip')).toHaveTextContent('1m 00s')
  })

  it('renders with custom formatter', async () => {
    await renderWithTooltip(
      <MetricValue
        {...valueProps('test_money', 5.3)}
        formatter={(value) => `${value}$`}
      />
    )

    expect(screen.getByTestId('metric-value')).toHaveTextContent('5.3$')
    expect(screen.getByRole('tooltip')).toHaveTextContent('5.3$')
  })

  it('renders revenue properly', async () => {
    await renderWithTooltip(
      <MetricValue {...valueProps('average_revenue', REVENUE)} />
    )

    expect(screen.getByTestId('metric-value')).toHaveTextContent('$1.7K')
    expect(screen.getByRole('tooltip')).toHaveTextContent('$1,659.50')
  })

  it('renders null revenue without tooltip', async () => {
    render(<MetricValue {...valueProps('average_revenue', null)} />)

    expect(screen.getByTestId('metric-value')).toHaveTextContent('-')

    await expect(waitForTooltip).rejects.toThrow()
  })
})

describe('comparisons', () => {
  it('renders increased metric', async () => {
    await renderWithTooltip(
      <MetricValue {...valueProps('visitors', 10, { value: 5, change: 100 })} />
    )

    expect(screen.getByTestId('metric-value')).toHaveTextContent('10↑')
    expect(screen.getByRole('tooltip')).toHaveTextContent(
      '10 visitors↑ 100%01 Aug - 31 Augvs5 visitors01 July - 31 July'
    )
  })

  it('renders decreased metric', async () => {
    await renderWithTooltip(
      <MetricValue {...valueProps('visitors', 5, { value: 10, change: -50 })} />
    )

    expect(screen.getByTestId('metric-value')).toHaveTextContent('5↓')
    expect(screen.getByRole('tooltip')).toHaveTextContent(
      '5 visitors↓ 50%01 Aug - 31 Augvs10 visitors01 July - 31 July'
    )
  })

  it('renders unchanged metric', async () => {
    await renderWithTooltip(
      <MetricValue {...valueProps('visitors', 10, { value: 10, change: 0 })} />
    )

    expect(screen.getByTestId('metric-value')).toHaveTextContent('10')
    expect(screen.getByRole('tooltip')).toHaveTextContent(
      '10 visitors〰 0%01 Aug - 31 Augvs10 visitors01 July - 31 July'
    )
  })

  it('renders metric with custom label', async () => {
    await renderWithTooltip(
      <MetricValue
        {...valueProps('visitors', 10, { value: 10, change: 0 })}
        renderLabel={() => 'Conversions'}
      />
    )

    expect(screen.getByRole('tooltip')).toHaveTextContent(
      '10 conversions〰 0%01 Aug - 31 Augvs10 conversions01 July - 31 July'
    )
  })

  it('does not render very short labels', async () => {
    await renderWithTooltip(
      <MetricValue
        {...valueProps('percentage', 10, { value: 10, change: 0 })}
        renderLabel={() => '%'}
      />
    )

    expect(screen.getByRole('tooltip')).toHaveTextContent(
      '10% 〰 0%01 Aug - 31 Augvs10% 01 July - 31 July'
    )
  })

  it('renders with custom formatter', async () => {
    await renderWithTooltip(
      <MetricValue
        {...valueProps('test', 10, { value: 5, change: 100 })}
        formatter={(value) => `${value}$`}
      />
    )

    expect(screen.getByTestId('metric-value')).toHaveTextContent('10$↑')
    expect(screen.getByRole('tooltip')).toHaveTextContent(
      '10$ test↑ 100%01 Aug - 31 Augvs5$ test01 July - 31 July'
    )
  })

  it('renders revenue change', async () => {
    await renderWithTooltip(
      <MetricValue
        {...valueProps('average_revenue', REVENUE, {
          value: REVENUE,
          change: 0
        })}
      />
    )

    expect(screen.getByTestId('metric-value')).toHaveTextContent('$1.7K')
    expect(screen.getByRole('tooltip')).toHaveTextContent(
      '$1,659.50 average_revenue〰 0%01 Aug - 31 Augvs$1,659.50 average_revenue01 July - 31 July'
    )
  })

  it('renders without tooltip when revenue null', async () => {
    render(
      <MetricValue
        {...valueProps('average_revenue', null, { value: null, change: 0 })}
      />
    )

    expect(screen.getByTestId('metric-value')).toHaveTextContent('-')

    await expect(waitForTooltip).rejects.toThrow()
  })
})

function valueProps<T>(
  metric: string,
  value: T,
  comparison?: { value: T; change: number }
) {
  return {
    metric: metric,
    listItem: {
      [metric]: value,
      comparison: comparison && {
        [metric]: comparison.value,
        change: {
          [metric]: comparison.change
        }
      }
    },
    meta: {
      date_range_label: '01 Aug - 31 Aug',
      comparison_date_range_label: '01 July - 31 July'
    },
    renderLabel: (_query: unknown) => metric.toUpperCase()
  } as any /* eslint-disable-line @typescript-eslint/no-explicit-any */
}

function render(ui: React.ReactNode) {
  const site = {
    flags: { breakdown_comparisons_ui: true }
  } as unknown as PlausibleSite
  libraryRender(<SiteContextProvider site={site}>{ui}</SiteContextProvider>)
}

async function renderWithTooltip(ui: React.ReactNode) {
  render(ui)
  await waitForTooltip()
}

async function waitForTooltip() {
  fireEvent.mouseOver(screen.getByTestId('metric-value'))
  await waitFor(() => screen.getByRole('tooltip'))
}
