/** @format */

import { formatISO, nowForSite, shiftMonths, yesterday } from './date'

jest.useFakeTimers()

describe(`${nowForSite.name} and ${formatISO.name}`, () => {
  /* prettier-ignore */
  const cases = [
    [ 'Los Angeles/America', -3600 * 6, '2024-11-01T20:00:00.000Z', '2024-11-01' ],
    [ 'Sydney/Australia', 3600 * 6, '2024-11-01T20:00:00.000Z', '2024-11-02' ]
  ]
  test.each(cases)(
    'in timezone of %s (offset %p) at %s, today is %s',
    (_tz, offset, utcTime, expectedToday) => {
      jest.setSystemTime(new Date(utcTime))
      expect(formatISO(nowForSite({ offset }))).toEqual(expectedToday)
    }
  )
})

/* prettier-ignore */
const dstChangeOverDayEstonia = [
//  system time                 today         yesterday     today-2mo     today+2mo     today-12mo    offset 
  [ '2024-03-30T21:00:00.000Z', '2024-03-30', '2024-03-29', '2024-01-30', '2024-05-30', '2023-03-30', 7200 ],
  [ '2024-03-30T22:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 7200 ],
  [ '2024-03-30T23:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 7200 ],
  [ '2024-03-31T00:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 7200 ],
  [ '2024-03-31T01:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 10800 ], // <-- all European TZs change to DST at 1AM UTC
  [ '2024-03-31T02:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 10800 ],
  [ '2024-03-31T03:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 10800 ],
  [ '2024-03-31T04:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 10800 ],
  // ...
  [ '2024-03-31T20:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 10800 ],
  [ '2024-03-31T21:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', 10800 ],
  [ '2024-03-31T22:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', 10800 ],
  [ '2024-03-31T23:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', 10800 ]
]

/* prettier-ignore */
const dstChangeOverDayGermany = [
//  system time                 today         yesterday     today-2mo     today+2mo     today-12mo    offset 
  [ '2024-03-30T21:00:00.000Z', '2024-03-30', '2024-03-29', '2024-01-30', '2024-05-30', '2023-03-30', 3600 ],
  [ '2024-03-30T22:00:00.000Z', '2024-03-30', '2024-03-29', '2024-01-30', '2024-05-30', '2023-03-30', 3600 ],
  [ '2024-03-30T23:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 3600 ],
  [ '2024-03-31T00:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 3600 ],
  [ '2024-03-31T01:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 7200 ], // <-- all European TZs change to DST at 1AM UTC
  [ '2024-03-31T02:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 7200 ],
  [ '2024-03-31T03:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 7200 ],
  [ '2024-03-31T04:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 7200 ],
  // ...
  [ '2024-03-31T20:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 7200 ],
  [ '2024-03-31T21:00:00.000Z', '2024-03-31', '2024-03-30', '2024-01-31', '2024-05-31', '2023-03-31', 7200 ],
  [ '2024-03-31T22:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', 7200 ],
  [ '2024-03-31T23:00:00.000Z', '2024-04-01', '2024-03-31', '2024-02-01', '2024-06-01', '2023-04-01', 7200 ]
]

/* prettier-ignore */
const dstChangeOverDayEgypt = [
//  system time                 today         yesterday     today-2mo     today+2mo     today-12mo    offset 
  [ '2024-10-31T20:00:00.000Z', '2024-10-31', '2024-10-30', '2024-08-31', '2024-12-31', '2023-10-31', 10800 ],
  [ '2024-10-31T20:59:59.999Z', '2024-10-31', '2024-10-30', '2024-08-31', '2024-12-31', '2023-10-31', 10800 ], // <-- changeover from DST is on Nov 1st 00:00 local time
  [ '2024-10-31T21:00:00.000Z', '2024-10-31', '2024-10-30', '2024-08-31', '2024-12-31', '2023-10-31', 7200 ], 
  [ '2024-10-31T21:59:59.999Z', '2024-10-31', '2024-10-30', '2024-08-31', '2024-12-31', '2023-10-31', 7200 ], 
  [ '2024-10-31T22:00:00.000Z', '2024-11-01', '2024-10-31', '2024-09-01', '2025-01-01', '2023-11-01', 7200 ],
]

const sets = [
  ['Europe/Tallinn', dstChangeOverDayEstonia],
  ['Europe/Berlin', dstChangeOverDayGermany],
  ['Africa/Cairo', dstChangeOverDayEgypt]
] as const

for (const [timezone, suite] of sets) {
  describe(`in timezone of ${timezone}, given the correct offset`, () => {
    it.each(suite)(
      'at system time %s, today is %s and yesterday is %s',
      (
        utcTime,
        expectedToday,
        expectedYesterday,
        expectedTwoMonthsBack,
        expectedTwoMonthsAhead,
        expectedOneYearBack,
        offset
      ) => {
        jest.setSystemTime(new Date(utcTime))
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
