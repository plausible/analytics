defmodule PlausibleE2E.Case do
  @moduledoc """
  Case template of the browser suite in `test/e2e_pw`, a port of the Playwright specs in `e2e/`.

  `Playwright.Case` gives every test a `context` and `page`; this adds Playwright Test's
  `request` fixture and the helpers of `e2e/tests/fixtures.ts` and `e2e/tests/test-utils.ts`.
  Run with `MIX_ENV=e2e_test mix test test/e2e_pw`.
  """
  use ExUnit.CaseTemplate

  using opts do
    quote do
      use Playwright.Case, unquote(opts)

      import PlausibleE2E.Fixtures
      import PlausibleE2E.Utils

      alias Playwright.{
        APIRequest,
        APIRequestContext,
        APIResponse,
        Dialog,
        Promise
      }

      @moduletag :e2e

      setup %{browser: browser} do
        playwright = Playwright.Test.BrowserPool.playwright(browser)
        request = APIRequest.new_context!(Playwright.request(playwright))
        %{request: request}
      end
    end
  end
end
