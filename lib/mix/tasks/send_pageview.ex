defmodule Mix.Tasks.SendPageview do
  @moduledoc """
  It's often necessary to generate fake events for development and testing purposes. This Mix Task provides a quick and easy
  way to generate a pageview or custom event, either in your development environment or a remote Plausible instance.

  See Mix.Tasks.SendPageview.usage/1 for more detailed documentation.
  """

  use Mix.Task
  require Logger

  @default_host "http://localhost:8000"
  @default_ip_address "127.0.0.1"
  @default_user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36 OPR/71.0.3770.284"
  @default_domain "dummy.site"
  @default_page "/"
  @default_referrer "https://google.com"
  @default_event "pageview"
  @default_props "{}"
  @default_queryparams ""
  @options [
    ip: :string,
    user_agent: :string,
    domain: :string,
    page: :string,
    referrer: :string,
    host: :string,
    hostname: :string,
    event: :string,
    props: :string,
    revenue_currency: :string,
    revenue_amount: :string,
    queryparams: :string
  ]

  def run(opts) do
    Finch.start_link(name: Plausible.Finch)

    {parsed, _, invalid} = OptionParser.parse(opts, strict: @options)

    case invalid do
      [] ->
        do_send_pageview(parsed)

      [invalid_option | _] ->
        {key, _val} = invalid_option
        IO.puts("Invalid option #{key}. Aborting.")
        IO.puts(usage())
    end
  end

  defp do_send_pageview(parsed_opts) do
    ip = Keyword.get(parsed_opts, :ip, @default_ip_address)
    user_agent = Keyword.get(parsed_opts, :user_agent, @default_user_agent)
    host = Keyword.get(parsed_opts, :host, @default_host)

    url = get_url(host)
    headers = get_headers(ip, user_agent)
    body = get_body(parsed_opts)

    case Plausible.HTTPClient.post(url, headers, body) do
      {:ok, resp} ->
        IO.puts(
          "✅ Successfully sent #{body[:name]} event to #{url} ✅ \n\nip=#{ip}\nuser_agent=#{user_agent}\nbody= #{inspect(body, pretty: true)}"
        )

        IO.puts("Response headers: " <> inspect(resp.headers, pretty: true))

      {:error, e} ->
        IO.puts("❌ Could not send event to #{url}. Got the following error: \n\n #{inspect(e)}")
    end
  end

  defp get_url(host) do
    Path.join(host, "/api/event")
  end

  defp get_headers(ip, user_agent) do
    [
      {"x-forwarded-for", ip},
      {"user-agent", user_agent},
      {"content-type", "text/plain"}
    ]
  end

  defp get_body(opts) do
    domain = Keyword.get(opts, :domain, @default_domain)
    page = Keyword.get(opts, :page, @default_page)
    referrer = Keyword.get(opts, :referrer, @default_referrer)
    event = Keyword.get(opts, :event, @default_event)
    props = Keyword.get(opts, :props, @default_props)
    hostname = Keyword.get(opts, :hostname, domain)
    queryparams = Keyword.get(opts, :queryparams, @default_queryparams)

    revenue =
      if Keyword.get(opts, :revenue_currency) do
        %{
          currency: Keyword.get(opts, :revenue_currency),
          amount: Keyword.get(opts, :revenue_amount)
        }
      end

    %{
      name: event,
      url: "http://#{hostname}#{page}?#{queryparams}",
      domain: domain,
      referrer: referrer,
      props: props,
      revenue: revenue
    }
  end

  defp usage() do
    """
    usage: $ mix send_pageview [--domain domain] [--ip ip_address]"
    options: #{inspect(@options, pretty: true)}
    """
  end
end
