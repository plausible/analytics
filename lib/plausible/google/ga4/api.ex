defmodule Plausible.Google.GA4.API do
  @moduledoc """
  API for Google Analytics 4.
  """

  alias Plausible.Google
  alias Plausible.Google.GA4

  require Logger

  @type import_auth :: {
          access_token :: String.t(),
          refresh_token :: String.t(),
          expires_at :: String.t()
        }

  @per_page 50_000
  @backoff_factor :timer.seconds(10)
  @max_attempts 5

  def list_properties(access_token) do
    case GA4.HTTP.list_accounts_for_user(access_token) do
      {:ok, %{"accountSummaries" => accounts}} ->
        accounts =
          accounts
          |> Enum.filter(& &1["propertySummaries"])
          |> Enum.map(fn account ->
            {"#{account["displayName"]} (#{account["account"]})",
             Enum.map(account["propertySummaries"], fn property ->
               {"#{property["displayName"]} (#{property["property"]})", property["property"]}
             end)}
          end)

        {:ok, accounts}

      error ->
        error
    end
  end

  def get_property(access_token, lookup_property) do
    case list_properties(access_token) do
      {:ok, properties} ->
        property =
          properties
          |> Enum.map(&elem(&1, 1))
          |> List.flatten()
          |> Enum.find(fn {_name, property} -> property == lookup_property end)

        {:ok, property}

      {:error, cause} ->
        {:error, cause}
    end
  end

  def get_analytics_start_date(access_token, property) do
    GA4.HTTP.get_analytics_start_date(access_token, property)
  end

  def import_analytics(date_range, property, auth, persist_fn) do
    Logger.debug(
      "[#{inspect(__MODULE__)}:#{property}] Starting import from #{date_range.first} to #{date_range.last}"
    )

    with {:ok, access_token} <- Google.API.maybe_refresh_token(auth) do
      do_import_analytics(date_range, property, access_token, persist_fn)
    end
  end

  defp do_import_analytics(date_range, property, access_token, persist_fn) do
    Enum.reduce_while(GA4.ReportRequest.full_report(), :ok, fn report_request, :ok ->
      Logger.debug(
        "[#{inspect(__MODULE__)}:#{property}] Starting to import #{report_request.dataset}"
      )

      report_request = prepare_request(report_request, date_range, property, access_token)

      case fetch_and_persist(report_request, persist_fn: persist_fn) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  @spec fetch_and_persist(GA4.ReportRequest.t(), Keyword.t()) ::
          :ok | {:error, term()}
  def fetch_and_persist(%GA4.ReportRequest{} = report_request, opts \\ []) do
    persist_fn = Keyword.fetch!(opts, :persist_fn)
    attempt = Keyword.get(opts, :attempt, 1)
    sleep_time = Keyword.get(opts, :sleep_time, @backoff_factor)

    case GA4.HTTP.get_report(report_request) do
      {:ok, {rows, row_count}} ->
        Logger.debug(
          "[#{inspect(__MODULE__)}:#{report_request.property}] Fetched #{length(rows)} rows of total #{row_count} with offset #{report_request.offset} for #{report_request.dataset}"
        )

        :ok = persist_fn.(report_request.dataset, rows)

        Logger.debug(
          "[#{inspect(__MODULE__)}:#{report_request.property}] Persisted #{length(rows)} for #{report_request.dataset}"
        )

        if report_request.offset + @per_page < row_count do
          fetch_and_persist(
            %GA4.ReportRequest{report_request | offset: report_request.offset + @per_page},
            opts
          )
        else
          :ok
        end

      {:error, cause} ->
        if attempt >= @max_attempts do
          Logger.debug(
            "[#{inspect(__MODULE__)}:#{report_request.property}] Request failed for #{report_request.dataset}. Terminating."
          )

          {:error, cause}
        else
          Logger.debug(
            "[#{inspect(__MODULE__)}:#{report_request.property}] Request failed for #{report_request.dataset}. Will retry."
          )

          Process.sleep(attempt * sleep_time)
          fetch_and_persist(report_request, Keyword.merge(opts, attempt: attempt + 1))
        end
    end
  end

  defp prepare_request(report_request, date_range, property, access_token) do
    %GA4.ReportRequest{
      report_request
      | date_range: date_range,
        property: property,
        access_token: access_token,
        offset: 0,
        limit: @per_page
    }
  end
end
