defmodule Plausible.Event.Language do
  @moduledoc """
  This module has functions to handle browser languages
  """

  @spec parse_accept_language(String.t() | nil) :: String.t() | nil
  @doc """
  Returns the preferred language of a browser from the [Accept-Language header](
  https://httpwg.org/specs/rfc7231.html#header.accept-language).

  This HTTP header is sent by clients to indicate preferred languages in the response. The client
  can have multiple languages, but only the topmost is returned. Language variation is stripped,
  e.g. `pt-BR` is transformed into `pt` to ensure this is a valid ISO 639 language code.

  Returns the parsed language code or nil.

  # Examples

    iex> parse_accept_language("pt-BR")
    "pt"

    iex> parse_accept_language("fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5")
    "fr"

    iex> parse_accept_language("de")
    "de"

    iex> parse_accept_language(";,")
    nil

    iex> parse_accept_language("*")
    nil

    iex> parse_accept_language("c̦͍̲̞͍̩̙ḥ͚a̮͎̟̙͜ơ̩̹͎s̤, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5")
    nil

  """
  def parse_accept_language(accept_language_header) do
    with languages when is_binary(languages) <- accept_language_header,
         preferred_languages <- get_first_substring(languages, ";"),
         preferred_language_with_variations <- get_first_substring(preferred_languages, ","),
         preferred_language <- get_first_substring(preferred_language_with_variations, "-"),
         preferred_language when byte_size(preferred_language) in 2..3 <- preferred_language do
      preferred_language
    else
      _any -> nil
    end
  end

  defp get_first_substring(string, separator) do
    string
    |> String.splitter(separator)
    |> Enum.at(0)
  end

  # https://github.com/datasets/language-codes
  @languages %{
    "aa" => "Afar",
    "ab" => "Abkhazian",
    "ae" => "Avestan",
    "af" => "Afrikaans",
    "ak" => "Akan",
    "am" => "Amharic",
    "an" => "Aragonese",
    "ar" => "Arabic",
    "as" => "Assamese",
    "av" => "Avaric",
    "ay" => "Aymara",
    "az" => "Azerbaijani",
    "ba" => "Bashkir",
    "be" => "Belarusian",
    "bg" => "Bulgarian",
    "bh" => "Bihari languages",
    "bm" => "Bambara",
    "bi" => "Bislama",
    "bn" => "Bengali",
    "bo" => "Tibetan",
    "br" => "Breton",
    "bs" => "Bosnian",
    "ca" => "Catalan",
    "ce" => "Chechen",
    "ch" => "Chamorro",
    "co" => "Corsican",
    "cr" => "Cree",
    "cs" => "Czech",
    "cu" => "Church Slavic",
    "cv" => "Chuvash",
    "cy" => "Welsh",
    "da" => "Danish",
    "de" => "German",
    "dv" => "Divehi",
    "dz" => "Dzongkha",
    "ee" => "Ewe",
    "el" => "Greek, Modern (1453-)",
    "en" => "English",
    "eo" => "Esperanto",
    "es" => "Spanish",
    "et" => "Estonian",
    "eu" => "Basque",
    "fa" => "Persian",
    "ff" => "Fulah",
    "fi" => "Finnish",
    "fj" => "Fijian",
    "fo" => "Faroese",
    "fr" => "French",
    "fy" => "Western Frisian",
    "ga" => "Irish",
    "gd" => "Gaelic",
    "gl" => "Galician",
    "gn" => "Guarani",
    "gu" => "Gujarati",
    "gv" => "Manx",
    "ha" => "Hausa",
    "he" => "Hebrew",
    "hi" => "Hindi",
    "ho" => "Hiri Motu",
    "hr" => "Croatian",
    "ht" => "Haitian Creole",
    "hu" => "Hungarian",
    "hy" => "Armenian",
    "hz" => "Herero",
    "ia" => "Interlingua (International Auxiliary Language Association)",
    "id" => "Indonesian",
    "ie" => "Interlingue",
    "ig" => "Igbo",
    "ii" => "Sichuan Yi",
    "ik" => "Inupiaq",
    "io" => "Ido",
    "is" => "Icelandic",
    "it" => "Italian",
    "iu" => "Inuktitut",
    "ja" => "Japanese",
    "jv" => "Javanese",
    "ka" => "Georgian",
    "kg" => "Kongo",
    "ki" => "Kikuyu",
    "kj" => "Kuanyama",
    "kk" => "Kazakh",
    "kl" => "Kalaallisut",
    "km" => "Central Khmer",
    "kn" => "Kannada",
    "ko" => "Korean",
    "kr" => "Kanuri",
    "ks" => "Kashmiri",
    "ku" => "Kurdish",
    "kv" => "Komi",
    "kw" => "Cornish",
    "ky" => "Kirghiz",
    "la" => "Latin",
    "lb" => "Luxembourgish",
    "lg" => "Ganda",
    "li" => "Limburgan",
    "ln" => "Lingala",
    "lo" => "Lao",
    "lt" => "Lithuanian",
    "lu" => "Luba-Katanga",
    "lv" => "Latvian",
    "mg" => "Malagasy",
    "mh" => "Marshallese",
    "mi" => "Maori",
    "mk" => "Macedonian",
    "ml" => "Malayalam",
    "mn" => "Mongolian",
    "mr" => "Marathi",
    "ms" => "Malay",
    "mt" => "Maltese",
    "my" => "Burmese",
    "na" => "Nauru",
    "nb" => "Norwegian Bokmål",
    "nd" => "North Ndebele",
    "ne" => "Nepali",
    "ng" => "Ndonga",
    "nl" => "Dutch",
    "nn" => "Norwegian Nynorsk",
    "no" => "Norwegian",
    "nr" => "South Ndebele",
    "nv" => "Navajo",
    "ny" => "Chichewa",
    "oc" => "Occitan (post 1500)",
    "oj" => "Ojibwa",
    "om" => "Oromo",
    "or" => "Oriya",
    "os" => "Ossetian",
    "pa" => "Panjabi",
    "pi" => "Pali",
    "pl" => "Polish",
    "ps" => "Pushto",
    "pt" => "Portuguese",
    "qu" => "Quechua",
    "rm" => "Romansh",
    "rn" => "Rundi",
    "ro" => "Romanian",
    "ru" => "Russian",
    "rw" => "Kinyarwanda",
    "sa" => "Sanskrit",
    "sc" => "Sardinian",
    "sd" => "Sindhi",
    "se" => "Northern Sami",
    "sg" => "Sango",
    "si" => "Sinhala",
    "sk" => "Slovak",
    "sl" => "Slovenian",
    "sm" => "Samoan",
    "sn" => "Shona",
    "so" => "Somali",
    "sq" => "Albanian",
    "sr" => "Serbian",
    "ss" => "Swati",
    "st" => "Sotho, Southern",
    "su" => "Sundanese",
    "sv" => "Swedish",
    "sw" => "Swahili",
    "ta" => "Tamil",
    "te" => "Telugu",
    "tg" => "Tajik",
    "th" => "Thai",
    "ti" => "Tigrinya",
    "tk" => "Turkmen",
    "tl" => "Tagalog",
    "tn" => "Tswana",
    "to" => "Tonga (Tonga Islands)",
    "tr" => "Turkish",
    "ts" => "Tsonga",
    "tt" => "Tatar",
    "tw" => "Twi",
    "ty" => "Tahitian",
    "ug" => "Uighur",
    "uk" => "Ukrainian",
    "ur" => "Urdu",
    "uz" => "Uzbek",
    "ve" => "Venda",
    "vi" => "Vietnamese",
    "vo" => "Volapük",
    "wa" => "Walloon",
    "wo" => "Wolof",
    "xh" => "Xhosa",
    "yi" => "Yiddish",
    "yo" => "Yoruba",
    "za" => "Zhuang",
    "zh" => "Chinese",
    "zu" => "Zulu"
  }

  @spec get_by_code(String.t()) :: String.t()
  @doc """
  Returns the English name for ISO 639-1 language codes.

  # Examples

    iex> get_by_code("zh")
    "Chinese"

    iex> get_by_code("invalid")
    "invalid"

  """
  def get_by_code(code) do
    Map.get(@languages, code, code)
  end
end
