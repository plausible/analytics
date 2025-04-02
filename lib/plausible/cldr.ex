defmodule Plausible.Cldr do
  @moduledoc false

  use Cldr, locales: ["en"], providers: [Cldr.Number, Money]
end
