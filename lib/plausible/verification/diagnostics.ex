defmodule Plausible.Verification.Diagnostics do
  @moduledoc """
  Module responsible for translating diagnostics to user-friendly errors and recommendations.
  """
  require Logger

  @errors Plausible.Verification.Errors.all()

  defstruct plausible_installed?: false,
            snippets_found_in_head: 0,
            snippets_found_in_body: 0,
            snippet_found_after_busting_cache?: false,
            snippet_unknown_attributes?: false,
            disallowed_via_csp?: false,
            service_error: nil,
            body_fetched?: false,
            wordpress_likely?: false,
            gtm_likely?: false,
            callback_status: 0,
            proxy_likely?: false,
            data_domain_mismatch?: false,
            wordpress_plugin?: false

  @type t :: %__MODULE__{}

  defmodule Result do
    @moduledoc """
    Diagnostics interpretation result.
    """
    defstruct ok?: false, errors: [], recommendations: []
    @type t :: %__MODULE__{}
  end

  @spec interpret(t(), String.t()) :: Result.t()
  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          snippets_found_in_head: 1,
          snippets_found_in_body: 0,
          callback_status: callback_status,
          snippet_found_after_busting_cache?: false,
          service_error: nil,
          data_domain_mismatch?: false
        },
        _url
      )
      when callback_status in [200, 202] do
    %Result{ok?: true}
  end

  def interpret(%__MODULE__{plausible_installed?: false, gtm_likely?: true}, _url) do
    error(@errors.gtm)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippets_found_in_head: 1,
          disallowed_via_csp?: true,
          proxy_likely?: false
        },
        _url
      ) do
    error(@errors.csp)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippets_found_in_head: 0,
          snippets_found_in_body: 0,
          body_fetched?: true,
          service_error: nil,
          wordpress_likely?: false
        },
        _url
      ) do
    error(@errors.no_snippet)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          body_fetched?: false
        },
        url
      ) do
    error(@errors.unreachable, url: url)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          service_error: service_error
        },
        _url
      )
      when not is_nil(service_error) do
    error(@errors.temporary)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          service_error: nil,
          body_fetched?: false
        },
        url
      ) do
    error(@errors.unreachable, url: url)
  end

  def interpret(
        %__MODULE__{
          snippets_found_in_body: 0,
          snippets_found_in_head: 1,
          plausible_installed?: true,
          wordpress_likely?: false,
          callback_status: -1
        },
        _url
      ) do
    error(@errors.old_script)
  end

  def interpret(
        %__MODULE__{
          snippets_found_in_body: 0,
          snippets_found_in_head: 1,
          plausible_installed?: true,
          wordpress_likely?: true,
          wordpress_plugin?: false,
          callback_status: -1
        },
        _url
      ) do
    error(@errors.old_script_wp_no_plugin)
  end

  def interpret(
        %__MODULE__{
          snippets_found_in_body: 0,
          snippets_found_in_head: 1,
          plausible_installed?: true,
          wordpress_likely?: true,
          wordpress_plugin?: true,
          callback_status: -1
        },
        _url
      ) do
    error(@errors.old_script_wp_plugin)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: 0,
          proxy_likely?: true
        },
        _url
      ) do
    error(@errors.proxy_misconfigured)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippets_found_in_head: 1,
          proxy_likely?: true,
          wordpress_likely?: true,
          wordpress_plugin?: false
        },
        _url
      ) do
    error(@errors.proxy_wp_no_plugin)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippets_found_in_head: 1,
          proxy_likely?: true,
          wordpress_likely?: false
        },
        _url
      ) do
    error(@errors.proxy_general)
  end

  def interpret(
        %__MODULE__{snippets_found_in_head: count_head, snippets_found_in_body: count_body},
        _url
      )
      when count_head + count_body > 1 do
    error(@errors.multiple_snippets)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: 202,
          snippet_found_after_busting_cache?: true,
          wordpress_likely?: true,
          wordpress_plugin?: true
        },
        _url
      ) do
    error(@errors.cache_wp_plugin)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: 202,
          snippet_found_after_busting_cache?: true,
          wordpress_likely?: true,
          wordpress_plugin?: false
        },
        _url
      ) do
    error(@errors.cache_wp_no_plugin)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: 202,
          snippet_found_after_busting_cache?: true,
          wordpress_likely?: false
        },
        _url
      ) do
    error(@errors.cache_general)
  end

  def interpret(%__MODULE__{snippets_found_in_head: 0, snippets_found_in_body: n}, _url)
      when n >= 1 do
    error(@errors.snippet_in_body)
  end

  def interpret(%__MODULE__{data_domain_mismatch?: true}, "https://" <> domain) do
    error(@errors.different_data_domain, domain: domain)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippet_unknown_attributes?: true,
          wordpress_likely?: true,
          wordpress_plugin?: true
        },
        _url
      ) do
    error(@errors.illegal_attrs_wp_plugin)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippet_unknown_attributes?: true,
          wordpress_likely?: true,
          wordpress_plugin?: false
        },
        _url
      ) do
    error(@errors.illegal_attrs_wp_no_plugin)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippet_unknown_attributes?: true,
          wordpress_likely?: false
        },
        _url
      ) do
    error(@errors.illegal_attrs_general)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          snippets_found_in_head: 0,
          snippets_found_in_body: 0,
          callback_status: callback_status,
          snippet_found_after_busting_cache?: false,
          service_error: nil
        },
        _url
      )
      when callback_status in [200, 202] do
    %Result{ok?: true}
  end

  def interpret(rating, url) do
    Sentry.capture_message("Unhandled case for site verification: #{url}",
      extra: %{
        message: inspect(rating)
      }
    )

    error(@errors.unknown)
  end

  defp error(error) do
    %Result{
      ok?: false,
      errors: [error.message],
      recommendations: [{error.recommendation, error.url}]
    }
  end

  defp error(error, assigns) do
    message = EEx.eval_string(error.message, assigns: assigns)
    error(%{error | message: message})
  end
end
