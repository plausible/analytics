defmodule Plausible.Test.Support.TLSServer do
  @moduledoc """
  Bypass-like HTTPS server for `Plausible.SSRF` tests, which only speaks HTTPS.
  """

  @behaviour Plug

  # Dev compiles test/support too, but Mox is test-only.
  @compile {:no_warn_undefined, Mox}

  @doc """
  Starts a server and returns `{ca, port}`.

    * `:cert_host` - name(s) the certificate is issued for
    * `:handler` - `fn conn, port -> conn end`; the port is for building redirects
  """
  def start(opts) do
    cert_hosts = opts |> Keyword.fetch!(:cert_host) |> List.wrap()
    {ca, cert, key} = certificate(cert_hosts)
    ref = make_ref()

    {:ok, _pid} =
      Plug.Cowboy.https(__MODULE__, [handler: Keyword.fetch!(opts, :handler), ref: ref],
        ref: ref,
        port: 0,
        cert: cert,
        key: {:ECPrivateKey, key}
      )

    ExUnit.Callbacks.on_exit(fn -> Plug.Cowboy.shutdown(ref) end)

    {ca, :ranch.get_port(ref)}
  end

  @doc """
  Lets `Plausible.SSRF` connect to 127.0.0.1 in the calling test. Every other
  address is still checked by `Plausible.IP.Tools`.
  """
  def allow_loopback do
    Mox.stub(Plausible.IP.Tools.Mock, :allowed?, fn
      {127, 0, 0, 1} -> true
      ip -> Plausible.IP.Tools.allowed?(ip)
    end)
  end

  @doc """
  Makes `Plausible.SSRF` check addresses with the real `Plausible.IP.Tools`.
  """
  def use_real_ip_check do
    Mox.stub_with(Plausible.IP.Tools.Mock, Plausible.IP.Tools)
    :ok
  end

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts), do: opts[:handler].(conn, :ranch.get_port(opts[:ref]))

  defp certificate(cert_hosts) do
    ca_key = X509.PrivateKey.new_ec(:secp256r1)
    ca = X509.Certificate.self_signed(ca_key, "/CN=SSRF Test CA", template: :root_ca)
    key = X509.PrivateKey.new_ec(:secp256r1)

    cert =
      key
      |> X509.PublicKey.derive()
      |> X509.Certificate.new("/CN=#{hd(cert_hosts)}", ca, ca_key,
        extensions: [subject_alt_name: X509.Certificate.Extension.subject_alt_name(cert_hosts)]
      )

    {X509.Certificate.to_der(ca), X509.Certificate.to_der(cert), X509.PrivateKey.to_der(key)}
  end
end
