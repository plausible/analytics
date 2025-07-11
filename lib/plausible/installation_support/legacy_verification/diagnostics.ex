defmodule Plausible.InstallationSupport.LegacyVerification.Diagnostics do
  @moduledoc """
  Module responsible for translating diagnostics to user-friendly errors and recommendations.
  """
  require Logger

  @errors Plausible.InstallationSupport.LegacyVerification.Errors.all()

  defstruct plausible_installed?: false,
            snippets_found_in_head: 0,
            snippets_found_in_body: 0,
            snippet_found_after_busting_cache?: false,
            snippet_unknown_attributes?: false,
            disallowed_via_csp?: false,
            service_error: nil,
            body_fetched?: false,
            wordpress_likely?: false,
            cookie_banner_likely?: false,
            gtm_likely?: false,
            callback_status: 0,
            proxy_likely?: false,
            manual_script_extension?: false,
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

  def interpret(
        %__MODULE__{plausible_installed?: false, gtm_likely?: true, disallowed_via_csp?: true},
        _url
      ) do
    error(@errors.csp)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          gtm_likely?: true,
          cookie_banner_likely?: true,
          wordpress_plugin?: false
        },
        _url
      ) do
    error(@errors.gtm_cookie_banner)
  end

  def interpret(
        %__MODULE__{plausible_installed?: false, gtm_likely?: true, wordpress_plugin?: false},
        _url
      ) do
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
          plausible_installed?: true,
          snippets_found_in_head: 0,
          snippets_found_in_body: 0,
          body_fetched?: true,
          gtm_likely?: false,
          callback_status: callback_status
        },
        _url
      )
      when is_integer(callback_status) and callback_status > 202 do
    error(@errors.no_snippet)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippets_found_in_head: 0,
          snippets_found_in_body: 0,
          body_fetched?: true,
          service_error: nil,
          wordpress_likely?: true
        },
        _url
      ) do
    error(@errors.no_snippet_wp)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          body_fetched?: false
        },
        _url
      ) do
    error(@errors.unreachable)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          service_error: :timeout
        },
        _url
      ) do
    error(@errors.generic)
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
        _url
      ) do
    error(@errors.unreachable)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          wordpress_likely?: false,
          callback_status: -1
        },
        _url
      ) do
    error(@errors.generic)
  end

  def interpret(
        %__MODULE__{
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
          callback_status: callback_status,
          proxy_likely?: true
        },
        _url
      )
      when callback_status in [0, 500] do
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

  def interpret(%__MODULE__{data_domain_mismatch?: true}, "https://" <> domain) do
    error(@errors.different_data_domain, domain: domain)
  end

  def interpret(
        %__MODULE__{
          snippets_found_in_head: count_head,
          snippets_found_in_body: count_body,
          manual_script_extension?: false
        },
        _url
      )
      when count_head + count_body > 1 do
    error(@errors.multiple_snippets)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: callback_status,
          snippet_found_after_busting_cache?: true,
          wordpress_likely?: true,
          wordpress_plugin?: true
        },
        _url
      )
      when callback_status in [200, 202] do
    error(@errors.cache_wp_plugin)
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: callback_status,
          snippet_found_after_busting_cache?: true,
          wordpress_likely?: true,
          wordpress_plugin?: false
        },
        _url
      )
      when callback_status in [200, 202] do
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

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          snippets_found_in_head: count_head,
          snippets_found_in_body: count_body,
          callback_status: callback_status,
          service_error: nil,
          manual_script_extension?: true
        },
        _url
      )
      when count_head + count_body > 1 and callback_status in [200, 202] do
    %Result{ok?: true}
  end

  def interpret(diagnostics, url) do
    Sentry.capture_message("Unhandled case for site verification",
      extra: %{
        message: inspect(diagnostics),
        url: url,
        hash: :erlang.phash2(diagnostics)
      }
    )

    error(@errors.unknown)
  end

  defp error(error) do
    %Result{
      ok?: false,
      errors: [error.message],
      recommendations: [%{text: error.recommendation, url: error.url}]
    }
  end

  defp error(error, assigns) do
    recommendation = EEx.eval_string(error.recommendation, assigns: assigns)
    error(%{error | recommendation: recommendation})
  end
end
