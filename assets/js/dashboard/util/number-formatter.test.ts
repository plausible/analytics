import {
  numberLongFormatter,
  numberShortFormatter,
  rateFormatter
} from './number-formatter'

describe('numberShortFormatter()', () => {
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

describe('rateFormatter()', () => {
  it('formats a rate that the API sends as a decimal string', () => {
    expect(rateFormatter('0')).toEqual('0%')
    expect(rateFormatter('100')).toEqual('100%')
    expect(rateFormatter('33.33')).toEqual('33.3%')
    expect(rateFormatter('50.0')).toEqual('50%')
  })

  it('keeps two decimals for a rate that is close to an extreme', () => {
    expect(rateFormatter('0.01')).toEqual('0.01%')
    expect(rateFormatter('0.05')).toEqual('0.05%')
    expect(rateFormatter('99.95')).toEqual('99.95%')
    expect(rateFormatter('99.99')).toEqual('99.99%')
  })

  it('keeps a pair of rates apart from 0% and 100%', () => {
    expect([rateFormatter('0.01'), rateFormatter('99.99')]).toEqual([
      '0.01%',
      '99.99%'
    ])
  })
})

describe('numberLongFormatter()', () => {
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
