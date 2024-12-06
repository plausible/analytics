import { numberLongFormatter, numberShortFormatter } from "./number-formatter"

describe("numberShortFormatter()", () => {
  it('converts to short format', () => {
    expect(numberShortFormatter(0)).toEqual('0')
    expect(numberShortFormatter(-10)).toEqual('-10')
    expect(numberShortFormatter(12)).toEqual('12')
    expect(numberShortFormatter(123)).toEqual('123')
    expect(numberShortFormatter(1234)).toEqual('1.2k')
    expect(numberShortFormatter(12345)).toEqual('12.3k')
    expect(numberShortFormatter(123456)).toEqual('123k')
    expect(numberShortFormatter(1234567)).toEqual('1.2M')
    expect(numberShortFormatter(12345678)).toEqual('12.3M')
    expect(numberShortFormatter(123456789)).toEqual('123M')
    expect(numberShortFormatter(1234567890)).toEqual('1.2B')
  })
})

describe("numberLongFormatter()", () => {
  it('converts to short format', () => {
    expect(numberLongFormatter(0)).toEqual('0')
    expect(numberLongFormatter(-10)).toEqual('-10')
    expect(numberLongFormatter(12)).toEqual('12')
    expect(numberLongFormatter(123)).toEqual('123')
    expect(numberLongFormatter(1234)).toEqual('1,234')
    expect(numberLongFormatter(12345)).toEqual('12,345')
    expect(numberLongFormatter(123456)).toEqual('123,456')
    expect(numberLongFormatter(1234567)).toEqual('1,234,567')
    expect(numberLongFormatter(12345678)).toEqual('12,345,678')
    expect(numberLongFormatter(123456789)).toEqual('123,456,789')
    expect(numberLongFormatter(1234567890)).toEqual('1,234,567,890')
  })
})
