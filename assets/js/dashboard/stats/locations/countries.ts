import worldJson from 'visionscarto-world-atlas/world/110m.json'
import countriesMeta from '../../../../data/countries_meta.json'
import * as topojson from 'topojson-client'

// The actual type is more extensive, this is only the part that we care about
export type WorldJsonCountryData = { properties: { a3: string } }

export function parseWorldTopoJsonToGeoJsonFeatures(): Array<WorldJsonCountryData> {
  const collection = topojson.feature(
    // @ts-expect-error strings in worldJson not recongizable as the enum values declared in library
    worldJson,
    worldJson.objects.countries
  )
  // @ts-expect-error topojson.feature return type incorrectly inferred as not a collection
  return collection.features
}

export type CountryEntry = {
  // alpha_3 is null for non-country override entries like "A1" (Anonymous VPN)
  alpha_3: string | null
  flag: string
}

type CountryTwoLetterCode = string

export type CountriesLookup = Record<CountryTwoLetterCode, CountryEntry>

const remapCountriesMeta = () => {
  const result: CountriesLookup = {}
  for (const [alpha_2, [alpha_3, flag]] of Object.entries(countriesMeta)) {
    // flag is definitely defined in the source file
    const entry: CountryEntry = { alpha_3, flag: flag! }
    Object.assign(result, { [alpha_2]: entry })
  }
  return result
}
export const COUNTRIES_BY_TWO_LETTER_CODE = remapCountriesMeta()
