defmodule Plausible.Goal.Revenue do
  @moduledoc """
  Currency specific functions for revenue goals
  """

  def revenue?(%Plausible.Goal{currency: currency}) do
    !!currency
  end

  def valid_currencies() do
    Ecto.Enum.dump_values(Plausible.Goal, :currency)
  end

  def currency_options() do
    options =
      for code <- valid_currencies() do
        {code, "#{code} - #{Cldr.Currency.display_name!(code)}"}
      end

    options
  end
end
