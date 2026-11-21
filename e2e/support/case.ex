defmodule PlausibleE2E.Case do
  @moduledoc """
  Case template of the browser suite in `e2e/`: `Playwright.Case` (a `context` and `page` per test)
  in the suite's one project, `chromium` (Desktop Chrome), plus Playwright Test's `request`
  fixture and the helpers of the suite.

  Run with `mix test.e2e`.
  """
  use ExUnit.CaseTemplate

  @doc "The `projects` of playwright.config.ts."
  def projects,
    do: [Playwright.Test.parameters([name: "chromium"] ++ Playwright.device("Desktop Chrome"))]

  using opts do
    quote do
      use Playwright.Case, [parameterize: PlausibleE2E.Case.projects()] ++ unquote(opts)

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
