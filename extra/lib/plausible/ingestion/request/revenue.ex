defmodule Plausible.Ingestion.Request.Revenue do
  @moduledoc """
  Revenue specific functions for the ingestion scope
  """

  def put_revenue_source(%Ecto.Changeset{} = changeset, %{} = request_body) do
    with revenue_source <- request_body["revenue"] || request_body["$"],
         %{"amount" => _, "currency" => _} = revenue_source <-
           Plausible.Helpers.JSON.decode_or_fallback(revenue_source) do
      parse_revenue_source(changeset, revenue_source)
    else
      _any -> changeset
    end
  end

  @valid_currencies Plausible.Goal.Revenue.valid_currencies()
  defp parse_revenue_source(changeset, %{"amount" => amount, "currency" => currency}) do
    with true <- currency in @valid_currencies,
         {%Decimal{} = amount, _rest} <- parse_decimal(amount),
         %Money{} = amount <- Money.new(currency, amount) do
      Ecto.Changeset.put_change(changeset, :revenue_source, amount)
    else
      _any -> changeset
    end
  end

  defp parse_decimal(value) do
    case value do
      value when is_binary(value) -> Decimal.parse(value)
      value when is_float(value) -> {Decimal.from_float(value), nil}
      value when is_integer(value) -> {Decimal.new(value), nil}
      _any -> :error
    end
  end
end
