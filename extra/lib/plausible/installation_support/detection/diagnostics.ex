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
    get_result("gtm", diagnostics)
  end

  def interpret(
        %__MODULE__{
          wordpress_likely: true,
          service_error: nil
        } = diagnostics,
        _url
      ) do
    get_result(
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
    get_result("npm", diagnostics)
  end

  def interpret(
        %__MODULE__{
          service_error: nil
        } = diagnostics,
        _url
      ) do
    get_result(PlausibleWeb.Tracker.fallback_installation_type(), diagnostics)
  end

  def interpret(
        %__MODULE__{
          service_error: service_error
        },
        _url
      )
      when service_error in [:domain_not_found, :invalid_url],
      do: %Result{ok?: false, data: nil, errors: [Atom.to_string(service_error)]}

  def interpret(%__MODULE__{} = _diagnostics, _url), do: unhandled_case()

  defp unhandled_case() do
    %Result{
      ok?: false,
      data: %{unhandled: true},
      errors: ["Unhandled detection case"]
    }
  end

  defp get_result(suggested_technology, diagnostics) do
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
