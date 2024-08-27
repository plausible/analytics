/** @format */

import { formatISO, nowForSite, yesterday } from './date'

jest.useFakeTimers()

const dstChangeOverDayEstonia = [
  ['2024-03-30T21:00:00.000Z', '2024-03-30', '2024-03-29', '7200'],
  ['2024-03-30T22:00:00.000Z', '2024-03-31', '2024-03-30', '7200'], // start of 31st March, 00:00
  ['2024-03-30T23:00:00.000Z', '2024-03-31', '2024-03-30', '7200'],
  ['2024-03-31T00:00:00.000Z', '2024-03-31', '2024-03-30', '7200'],
  ['2024-03-31T01:00:00.000Z', '2024-03-31', '2024-03-30', '7200'],
  ['2024-03-31T02:00:00.000Z', '2024-03-31', '2024-03-30', '7200'],
  ['2024-03-31T03:00:00.000Z', '2024-03-31', '2024-03-30', '10800'],
  ['2024-03-31T04:00:00.000Z', '2024-03-31', '2024-03-30', '10800'],
  // ...
  ['2024-03-31T20:00:00.000Z', '2024-03-31', '2024-03-30', '10800'],
  ['2024-03-31T21:00:00.000Z', '2024-03-31', '2024-03-30', '10800'],
  ['2024-03-31T22:00:00.000Z', '2024-04-01', '2024-03-31', '10800'], // start of 1st of April, 00:00
  ['2024-03-31T23:00:00.000Z', '2024-04-01', '2024-03-31', '10800']
]

it.each(dstChangeOverDayEstonia)(
  'at system time %s in Estonia, today is %s and yesterday is %s',
  (unixTime, expectedToday, expectedYesterday, offset) => {
    jest.setSystemTime(new Date(unixTime))
    expect({
      today: formatISO(nowForSite({ offset })),
      yesterday: formatISO(yesterday({ offset }))
    }).toEqual({ today: expectedToday, yesterday: expectedYesterday })
  }
)
