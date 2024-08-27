/** @format */

import { formatISO, nowForSite, shiftMonths, yesterday } from './date'

jest.useFakeTimers()

/* prettier-ignore */
const dstChangeOverDayEstonia = [
//  system time                 today         yesterday     today-2mo     today+2mo     today-12mo    offset 
  [ '2024-03-30T21:00:00.000Z', '2024-03-30', '2024-03-29', '2024-01-30', '2024-05-30', '2023-03-30', '7200' ],
  [ '2024-03-30T22:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '7200' ],
  [ '2024-03-30T23:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '7200' ],
  [ '2024-03-31T00:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '7200' ],
  [ '2024-03-31T01:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '7200' ],
  [ '2024-03-31T02:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '7200' ],
  [ '2024-03-31T03:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '10800' ],
  [ '2024-03-31T04:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '10800' ],
  // ...
  [ '2024-03-31T20:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '10800' ],
  [ '2024-03-31T21:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', '10800' ],
  [ '2024-03-31T22:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', '10800' ],
  [ '2024-03-31T23:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', '10800' ]
]

/* prettier-ignore */
const dstChangeOverDayGermany = [
//  system time                 today         yesterday     today-2mo     today+2mo     today-12mo    offset 
  [ '2024-03-30T21:00:00.000Z', '2024-03-30', '2024-03-29', '2024-01-30', '2024-05-30', '2023-03-30', '3600' ],
  [ '2024-03-30T22:00:00.000Z', '2024-03-30', '2024-03-29', '2024-01-30', '2024-05-30', '2023-03-30', '3600' ],
  [ '2024-03-30T23:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '3600' ],
  [ '2024-03-31T00:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '3600' ],
  [ '2024-03-31T01:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '3600' ],
  [ '2024-03-31T02:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '3600' ],
  [ '2024-03-31T03:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '7200' ],
  [ '2024-03-31T04:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '7200' ],
  // ...
  [ '2024-03-31T20:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '7200' ],
  [ '2024-03-31T21:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', '7200' ],
  [ '2024-03-31T22:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', '7200' ],
  [ '2024-03-31T23:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', '7200' ]
]

const sets = [
  ['Europe/Tallinn', dstChangeOverDayEstonia],
  ['Europe/Berlin', dstChangeOverDayGermany]
] as const

for (const [timezone, suite] of sets) {
  describe(`${timezone} (relying on offset)`, () => {
    it.each(suite)(
      'handles system time %s, today is %s and yesterday is %s',
      (
        unixTime,
        expectedToday,
        expectedYesterday,
        expectedTwoMonthsBack,
        expectedTwoMonthsAhead,
        expectedOneYearBack,
        offset
      ) => {
        jest.setSystemTime(new Date(unixTime))
        expect({
          today: formatISO(nowForSite({ offset })),
          yesterday: formatISO(yesterday({ offset })),
          twoMonthsBack: formatISO(shiftMonths(nowForSite({ offset }), -2)),
          twoMonthsAhead: formatISO(shiftMonths(nowForSite({ offset }), 2)),
          oneYearBack: formatISO(shiftMonths(nowForSite({ offset }), -12))
        }).toEqual({
          today: expectedToday,
          yesterday: expectedYesterday,
          twoMonthsBack: expectedTwoMonthsBack,
          twoMonthsAhead: expectedTwoMonthsAhead,
          oneYearBack: expectedOneYearBack
        })
      }
    )
  })
}

for (const [timezone, suite] of sets) {
  test('Node.js should have full ICU support for the following approach to work', () => {
    const frenchDate = new Intl.DateTimeFormat('fr-FR', {
      month: 'long'
    }).format(new Date(2024, 0, 1))
    const expectedFrenchMonth = 'janvier' // January in French

    expect(frenchDate).toBe(expectedFrenchMonth)
  })

  describe(`${timezone} alternative`, () => {
    it.each(suite)(
      'at system time %s, today is %s and yesterday is %s',
      (
        unixTime,
        expectedToday,
        expectedYesterday,
        expectedTwoMonthsBack,
        expectedTwoMonthsAhead,
        expectedOneYearBack
      ) => {
        jest.setSystemTime(new Date(unixTime))

        const alternativeFormatISO = (
          date: Date,
          { timezone }: { timezone: string }
        ): string =>
          // Canada has a convenient format that looks like "YYYY-MM-DD <time>"
          Intl.DateTimeFormat('en-CA', {
            timeZone: timezone
          })
            .format(date)
            .split(' ')
            .shift()!

        const alternativeYesterday = () => {
          const d = new Date()
          d.setDate(d.getDate() - 1)
          return d
        }

        const alternativeShiftMonths = (date: Date, months: number): Date => {
          const d = new Date(date)
          d.setMonth(d.getMonth() + months)
          return d
        }

        expect({
          today: alternativeFormatISO(new Date(), { timezone }),
          yesterday: alternativeFormatISO(alternativeYesterday(), {
            timezone
          }),
          twoMonthsBack: alternativeFormatISO(
            alternativeShiftMonths(new Date(), -2),
            {
              timezone
            }
          ),
          twoMonthsAhead: alternativeFormatISO(
            alternativeShiftMonths(new Date(), 2),
            {
              timezone
            }
          ),
          oneYearBack: alternativeFormatISO(
            alternativeShiftMonths(new Date(), -12),
            {
              timezone
            }
          )
        }).toEqual({
          today: expectedToday,
          yesterday: expectedYesterday,
          twoMonthsBack: expectedTwoMonthsBack,
          twoMonthsAhead: expectedTwoMonthsAhead,
          oneYearBack: expectedOneYearBack
        })
      }
    )
  })
}
