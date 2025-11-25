defmodule Plausible.InstallationSupport.Detection.Diagnostics do
  @moduledoc """
  Module responsible for translating diagnostics to user-friendly errors and recommendations.
  """
  require Logger

  # in this struct, nil means indeterminate
  defstruct v1_detected: nil,
            gtm_likely: nil,
            wordpress_likely: nil,
            wordpress_plugin: nil,
            npm: nil,
            service_error: nil

  @type t :: %__MODULE__{}

  alias Plausible.InstallationSupport.Result

  @spec interpret(t(), String.t()) :: Result.t()
  def interpret(
        %__MODULE__{
          gtm_likely: true,
          service_error: nil
        } = diagnostics,
        _url
      ) do
    success("gtm", diagnostics)
  end

  def interpret(
        %__MODULE__{
          wordpress_likely: true,
          service_error: nil
        } = diagnostics,
        _url
      ) do
    success(
      "wordpress",
      diagnostics
    )
  end

  def interpret(
        %__MODULE__{
          npm: true,
          service_error: nil
        } = diagnostics,
        _url
      ) do
    success("npm", diagnostics)
  end

  def interpret(
        %__MODULE__{
          service_error: nil
        } = diagnostics,
        _url
      ) do
    success(PlausibleWeb.Tracker.fallback_installation_type(), diagnostics)
  end

  def interpret(%__MODULE__{service_error: %{code: code}}, _url)
      when code in [:domain_not_found, :invalid_url] do
    failure(:customer_website_issue)
  end

  def interpret(%__MODULE__{service_error: %{code: code}}, _url)
      when code in [:bad_browserless_response, :browserless_timeout, :internal_check_timeout] do
    failure(:browserless_issue)
  end

  def interpret(
        %__MODULE__{service_error: %{code: :browserless_client_error, extra: extra}},
        _url
      ) do
    cond do
      String.contains?(extra, "net::") ->
        failure(:customer_website_issue)

      String.contains?(String.downcase(extra), "execution context") ->
        failure(:customer_website_issue)

      true ->
        failure(:unknown_issue)
    end
  end

  def interpret(%__MODULE__{} = _diagnostics, _url), do: failure(:unknown_issue)

  defp failure(reason) do
    %Result{
      ok?: false,
      data: %{failure: reason},
      errors: [reason]
    }
  end

  defp success(suggested_technology, diagnostics) do
    %Result{
      ok?: true,
      data: %{
        v1_detected: diagnostics.v1_detected,
        wordpress_plugin: diagnostics.wordpress_plugin,
        npm: diagnostics.npm,
        suggested_technology: suggested_technology
      }
    }
  end
end
