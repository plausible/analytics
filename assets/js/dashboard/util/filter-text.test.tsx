import React,{ ReactNode } from 'react'
import { DashboardQuery, Filter, FilterClauseLabels } from '../query'
import { plainFilterText, styledFilterText } from './filter-text'
import { render, screen } from '@testing-library/react'

describe('styledFilterText() and plainFilterText()', () => {
  it.each<[Filter, FilterClauseLabels, string]>([
    [['is', 'page', ['/docs', '/blog']], {}, 'Page is /docs or /blog'],
    [['is', 'country', ['US']], { US: 'United States' }, 'Country is United States'],
    [['is', 'goal', ['Signup']], {}, 'Goal is Signup'],
    [['is', 'props:browser_language', ['en-US']], {}, 'Property browser_language is en-US'],
    [['has_not_done', 'goal', ['Signup', 'Login']], {}, 'Has not done Goal Signup or Login'],
  ])(
    'when filter is %p and labels are %p, functions return %p',
    (filter, labels, expectedPlainText) => {
      const query = { labels } as unknown as DashboardQuery

      expect(plainFilterText(query, filter)).toBe(expectedPlainText)

      render(<p data-testid="filter-text">{styledFilterText(query, filter)}</p>)
      expect(screen.getByTestId('filter-text')).toHaveTextContent(expectedPlainText)
    }
  )
})
