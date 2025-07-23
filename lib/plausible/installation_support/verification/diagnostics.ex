defmodule Plausible.InstallationSupport.Verification.Diagnostics do
  @moduledoc """
  Module responsible for translating diagnostics to user-friendly errors and recommendations.
  """
  require Logger
  @errors Plausible.InstallationSupport.Verification.Errors.all()

  defstruct selected_installation_type: nil,
            disallowed_by_csp: nil,
            plausible_is_on_window: nil,
            plausible_is_initialized: nil,
            # TODO
            cache_bust_something: nil,
            # from u and d values, derive if proxy and domain match
            test_event_request: nil,
            # overlap with test_evenrt_request, needed? maybe derive if window.plausible function signature has callback implemented like we expect
            test_event_callback_result: nil,
            # actually cookie_banner_blocking_plausible_likely :)
            cookie_banner_likely: nil,
            service_error: nil

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
          service_error: nil
        },
        _url
      ) do
    %Result{ok?: true}
  end

  def interpret(%__MODULE__{service_error: _service_error} = diagnostics, url) do
    cond do
      true ->
        Sentry.capture_message("Unhandled case for site verification",
          extra: %{
            message: inspect(diagnostics),
            url: url,
            hash: :erlang.phash2(diagnostics)
          }
        )

        %Result{
          ok?: false,
          errors: [@errors.unknown.message],
          recommendations: [@errors.unknown.recommendation]
        }
    end
  end
end
