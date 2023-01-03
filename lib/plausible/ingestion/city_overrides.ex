defmodule Plausible.Ingestion.CityOverrides do
  @moduledoc false

  @overrides %{
    # Austria
    # Gemeindebezirk Floridsdorf -> Vienna
    2_779_467 => 2_761_369,
    # Gemeindebezirk Leopoldstadt -> Vienna
    2_772_614 => 2_761_369,
    # Gemeindebezirk Landstrasse -> Vienna
    2_773_040 => 2_761_369,
    # Gemeindebezirk Donaustadt -> Vienna
    2_780_851 => 2_761_369,
    # Gemeindebezirk Favoriten -> Vienna
    2_779_776 => 2_761_369,
    # Gemeindebezirk Währing -> Vienna
    2_762_091 => 2_761_369,
    # Gemeindebezirk Wieden -> Vienna
    2_761_393 => 2_761_369,
    # Gemeindebezirk Innere Stadt -> Vienna
    2_775_259 => 2_761_369,
    # Gemeindebezirk Alsergrund -> Vienna
    2_782_729 => 2_761_369,
    # Gemeindebezirk Liesing -> Vienna
    2_772_484 => 2_761_369,
    # Urfahr -> Linz
    2_762_518 => 2_772_400,

    # Canada
    # Old Toronto -> Toronto
    8_436_019 => 6_167_865,
    # Etobicoke -> Toronto
    5_950_267 => 6_167_865,
    # East York -> Toronto
    5_946_235 => 6_167_865,
    # Scarborough -> Toronto
    6_948_711 => 6_167_865,
    # North York -> Toronto
    6_091_104 => 6_167_865,

    # Czech republic
    # Praha 5 -> Prague
    11_951_220 => 3_067_696,
    # Praha 4 -> Prague
    11_951_218 => 3_067_696,
    # Praha 11 -> Prague
    11_951_232 => 3_067_696,
    # Praha 10 -> Prague
    11_951_210 => 3_067_696,
    # Praha 4 -> Prague
    8_378_772 => 3_067_696,

    # Denmark
    # København SV -> Copenhagen
    11_747_123 => 2_618_425,
    # København NV -> Copenhagen
    11_746_894 => 2_618_425,
    # Odense S -> Odense
    11_746_825 => 2_615_876,
    # Odense M -> Odense
    11_746_974 => 2_615_876,
    # Odense SØ -> Odense
    11_746_888 => 2_615_876,
    # Aarhus C -> Aarhus
    11_746_746 => 2_624_652,
    # Aarhus N -> Aarhus
    11_746_890 => 2_624_652,

    # Estonia
    # Kristiine linnaosa -> Tallinn
    11_050_530 => 588_409,
    # Kesklinna linnaosa -> Tallinn
    11_053_706 => 588_409,
    # Lasnamäe linnaosa -> Tallinn
    11_050_526 => 588_409,
    # Põhja-Tallinna linnaosa -> Tallinn
    11_049_594 => 588_409,
    # Mustamäe linnaosa -> Tallinn
    11_050_531 => 588_409,
    # Haabersti linnaosa -> Tallinn
    11_053_707 => 588_409,
    # Viimsi -> Tallinn
    587_629 => 588_409,

    # Germany
    # Bezirk Tempelhof-Schöneberg -> Berlin
    3_336_297 => 2_950_159,
    # Bezirk Mitte -> Berlin
    2_870_912 => 2_950_159,
    # Bezirk Charlottenburg-Wilmersdorf -> Berlin
    3_336_294 => 2_950_159,
    # Bezirk Friedrichshain-Kreuzberg -> Berlin
    3_336_295 => 2_950_159,
    # Moosach -> Munich
    8_351_447 => 2_867_714,
    # Schwabing-Freimann -> Munich
    8_351_448 => 2_867_714,
    # Stadtbezirk 06 -> Düsseldorf
    6_947_276 => 2_934_246,
    # Stadtbezirk 04 -> Düsseldorf
    6_947_274 => 2_934_246,
    # Köln-Ehrenfeld -> Köln
    6_947_479 => 2_886_242,
    # Köln-Lindenthal- -> Köln
    6_947_481 => 2_886_242,
    # Beuel -> Bonn
    2_949_619 => 2_946_447,
    # Innenstadt I -> Frankfurt am Main
    6_946_225 => 2_925_533,
    # Innenstadt II -> Frankfurt am Main
    6_946_226 => 2_925_533,
    # Innenstadt III -> Frankfurt am Main
    6_946_227 => 2_925_533,

    # India
    # Navi Mumbai -> Mumbai
    6_619_347 => 1_275_339,

    # Mexico
    # Miguel Hidalgo Villa Olímpica -> Mexico city
    11_561_026 => 3_530_597,
    # Zedec Santa Fe -> Mexico city
    3_517_471 => 3_530_597,
    #  Fuentes del Pedregal-> Mexico city
    11_562_596 => 3_530_597,
    #  Centro -> Mexico city
    9_179_691 => 3_530_597,
    #  Cuauhtémoc-> Mexico city
    12_266_959 => 3_530_597,

    # Netherlands
    # Schiphol-Rijk -> Amsterdam
    10_173_838 => 2_759_794,
    # Westpoort -> Amsterdam
    11_525_047 => 2_759_794,
    # Amsterdam-Zuidoost -> Amsterdam
    6_544_881 => 2_759_794,
    # Loosduinen -> The Hague
    11_525_037 => 2_747_373,
    # Laak -> The Hague
    11_525_042 => 2_747_373,

    # Norway
    # Nordre Aker District -> Oslo
    6_940_981 => 3_143_244,

    # Romania
    # Sector 1 -> Bucharest,
    11_055_041 => 683_506,
    # Sector 2 -> Bucharest
    11_055_040 => 683_506,
    # Sector 3 -> Bucharest
    11_055_044 => 683_506,
    # Sector 4 -> Bucharest
    11_055_042 => 683_506,
    # Sector 5 -> Bucharest
    11_055_043 => 683_506,
    # Sector 6 -> Bucharest
    11_055_039 => 683_506,
    # Bucuresti -> Bucharest
    6_691_781 => 683_506,

    # Slovakia
    # Bratislava -> Bratislava
    3_343_955 => 3_060_972,

    # Sweden
    # Södermalm -> Stockholm
    2_676_209 => 2_673_730,

    # Switzerland
    # Vorstädte -> Basel
    11_789_440 => 2_661_604,
    # Zürich (Kreis 11) / Oerlikon -> Zürich
    2_659_310 => 2_657_896,
    # Zürich (Kreis 3) / Alt-Wiedikon -> Zürich
    2_658_007 => 2_657_896,
    # Zürich (Kreis 5) -> Zürich
    6_295_521 => 2_657_896,
    # Zürich (Kreis 1) / Hochschulen -> Zürich
    6_295_489 => 2_657_896,

    # UK
    # Shadwell -> London
    6_690_595 => 2_643_743,
    # City of London -> London
    2_643_741 => 2_643_743,
    # South Bank -> London
    6_545_251 => 2_643_743,
    # Soho -> London
    6_545_173 => 2_643_743,
    # Whitechapel -> London
    2_634_112 => 2_643_743,
    # King's Cross -> London
    6_690_589 => 2_643_743,
    # Poplar -> London
    2_640_091 => 2_643_743,
    # Hackney -> London
    2_647_694 => 2_643_743
  }
  def get(key, default), do: Map.get(@overrides, key, default)
end
