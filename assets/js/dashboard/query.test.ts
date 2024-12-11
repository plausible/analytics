/** @format */

import { maybeGetRedirectTargetFromLegacySearchParams } from './query'

describe(`${maybeGetRedirectTargetFromLegacySearchParams.name}`, () => {
  it.each([
    [''],
    ['?auth=_Y6YOjUl2beUJF_XzG1hk&theme=light&background=%23ee00ee'],
    ['?keybindHint=Escape&with_imported=true'],
    ['?f=is,page,/blog/:category/:article-name&date=2024-10-10&period=day'],
    ['?f=is,country,US&l=US,United%20States']
  ])('for modern search %p returns null', (search) => {
    expect(
      maybeGetRedirectTargetFromLegacySearchParams({
        pathname: '/example.com%2Fdeep%2Fpath',
        search
      } as Location)
    ).toBeNull()
  })

  it('returns updated URL for jsonurl style filters, and running the updated value through the function again returns null (no redirect loop)', () => {
    const pathname = '/'
    const search =
      '?filters=((is,exit_page,(/plausible.io)),(is,source,(Brave)),(is,city,(993800)))&labels=(993800:Johannesburg)'
    const expectedUpdatedSearch =
      '?f=is,exit_page,/plausible.io&f=is,source,Brave&f=is,city,993800&l=993800,Johannesburg'
    expect(
      maybeGetRedirectTargetFromLegacySearchParams({
        pathname,
        search
      } as Location)
    ).toEqual(`${pathname}${expectedUpdatedSearch}`)
    expect(
      maybeGetRedirectTargetFromLegacySearchParams({
        pathname,
        search: expectedUpdatedSearch
      } as Location)
    ).toBeNull()
  })

  it('returns updated URL for page=... style filters, and running the updated value through the function again returns null (no redirect loop)', () => {
    const pathname = '/'
    const search = '?page=/docs'
    const expectedUpdatedSearch = '?f=is,page,/docs'
    expect(
      maybeGetRedirectTargetFromLegacySearchParams({
        pathname,
        search
      } as Location)
    ).toEqual(`${pathname}${expectedUpdatedSearch}`)
    expect(
      maybeGetRedirectTargetFromLegacySearchParams({
        pathname,
        search: expectedUpdatedSearch
      } as Location)
    ).toBeNull()
  })
})
