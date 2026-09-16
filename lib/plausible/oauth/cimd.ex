defmodule Plausible.OAuth.CIMD do
  @moduledoc """
  This module fetches and validates [Client ID Metadata Documents](https://datatracker.ietf.org/doc/draft-ietf-oauth-client-id-metadata-document/).
  """

  @fetch_timeout 5_000
  @max_metadata_bytes 1_000_000
  @max_client_name_length 255
  @max_client_id_length 2048
  @max_redirect_uri_length 2048

  @doc """
  Fetches and validates a Client ID Metadata Document.
  """
  @spec fetch(String.t()) :: {:ok, map()} | {:error, atom() | Exception.t()}
  def fetch(client_id) do
    with :ok <- validate_client_id(client_id),
         {:ok, body} <- ssrf_get(client_id),
         {:ok, doc} <- decode_metadata(body),
         :ok <- validate_document(doc, client_id) do
      {:ok, doc}
    end
  end

  @doc """
  Validates a `client_id`.
  Must
  - use `https` scheme
  - have path component (`/` counts as a path component)
  - not have userinfo, e.g. `https://example.com@evil.com`
  - not have fragment, e.g. `https://example.com/doc#foobar`
  - not have dot segments, e.g. `https://example.com/metadata/./..`
  """
  @spec validate_client_id(String.t() | term()) ::
          :ok | {:error, :client_id_not_https | :invalid_client_id | :client_id_too_long}
  def validate_client_id(url) when is_binary(url) and byte_size(url) > @max_client_id_length do
    {:error, :client_id_too_long}
  end

  def validate_client_id(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, userinfo: nil, fragment: nil, path: path}
      when is_binary(host) and host != "" and is_binary(path) and path != "" ->
        if dot_segments?(path), do: {:error, :invalid_client_id}, else: :ok

      %URI{scheme: "https", host: host} when is_binary(host) and host != "" ->
        {:error, :invalid_client_id}

      _ ->
        {:error, :client_id_not_https}
    end
  end

  def validate_client_id(_), do: {:error, :client_id_not_https}

  # Detects `.` and `..` path segments, including when they're encoded with `%2e` and `%2E`.
  defp dot_segments?(path) do
    path
    |> String.split("/")
    |> Enum.any?(fn segment ->
      (segment |> String.downcase() |> String.replace("%2e", ".")) in [".", ".."]
    end)
  end

  defp ssrf_get(url) do
    opts =
      [receive_timeout: @fetch_timeout, decode_body: false]
      |> Keyword.merge(Application.get_env(:plausible, __MODULE__, [])[:req_opts] || [])

    case Plausible.SSRF.get(url, opts) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        if byte_size(body) > @max_metadata_bytes do
          {:error, :client_metadata_too_large}
        else
          {:ok, body}
        end

      {:ok, %Req.Response{}} ->
        {:error, :client_metadata_unavailable}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_metadata(body) do
    case JSON.decode(body) do
      {:ok, doc} when is_map(doc) -> {:ok, doc}
      _ -> {:error, :invalid_client_metadata}
    end
  end

  @doc """
  Validates a fetched Client ID Metadata Document against the `client_id` it was
  fetched from.
  """
  @spec validate_document(map(), String.t()) ::
          :ok
          | {:error,
             :client_id_mismatch
             | :missing_redirect_uris
             | :invalid_redirect_uris
             | :invalid_client_name}
  def validate_document(doc, client_id) do
    with :ok <- validate_self_reference(doc, client_id),
         :ok <- validate_redirect_uris(doc["redirect_uris"]) do
      validate_client_name(doc["client_name"])
    end
  end

  @doc """
  Checks that a metadata document is self-referential: its own `client_id` is
  the URL it was fetched from.

  A document that names a different `client_id` describes someone else, and the
  `client_id` is what is stored on every code and grant and shown on the consent
  screen - so a document is only allowed to speak for the URL it lives at.
  """
  @spec validate_self_reference(map(), String.t()) :: :ok | {:error, :client_id_mismatch}
  def validate_self_reference(doc, client_id) do
    if doc["client_id"] == client_id, do: :ok, else: {:error, :client_id_mismatch}
  end

  @doc """
  Validates a metadata document's `redirect_uris` entry.

  Accepts redirect URIs with format
  - `https://` URL
  - `http://` URL on a loopback host
  - custom scheme when it contains a dot (e.g. `io.plausible://...`)

  The URI must not have a fragment.

  All redirect_uris entries must be valid.
  """
  @spec validate_redirect_uris(term()) ::
          :ok | {:error, :missing_redirect_uris | :invalid_redirect_uris}
  def validate_redirect_uris(redirect_uris) when is_list(redirect_uris) and redirect_uris != [] do
    if Enum.all?(redirect_uris, &valid_redirect_uri?/1) do
      :ok
    else
      {:error, :invalid_redirect_uris}
    end
  end

  def validate_redirect_uris(_redirect_uris), do: {:error, :missing_redirect_uris}

  defp valid_redirect_uri?(uri)
       when is_binary(uri) and byte_size(uri) <= @max_redirect_uri_length do
    case URI.parse(uri) do
      %URI{fragment: fragment} when not is_nil(fragment) -> false
      %URI{userinfo: userinfo} when not is_nil(userinfo) -> false
      %URI{scheme: "https", host: host} -> is_binary(host) and host != ""
      %URI{scheme: "http", host: host} -> loopback_host?(host)
      %URI{scheme: scheme} when is_binary(scheme) -> String.contains?(scheme, ".")
      _ -> false
    end
  end

  defp valid_redirect_uri?(_uri), do: false

  @doc """
  Validates a metadata document's `client_name` entry.
  """
  @spec validate_client_name(term()) :: :ok | {:error, :invalid_client_name}
  def validate_client_name(nil), do: :ok

  def validate_client_name(name) when is_binary(name) do
    if String.trim(name) != "" and String.length(name) <= @max_client_name_length and
         not unreadable?(name) do
      :ok
    else
      {:error, :invalid_client_name}
    end
  end

  def validate_client_name(_name), do: {:error, :invalid_client_name}

  # Forbids certain names.
  # Control characters (C0, DEL, C1) truncate or garble the identity line.
  # Bidi overrides `U+202A`-`U+202E` and isolates `U+2066`-`U+2069`
  # reorder the glyphs around them, so a name can be made to render as a different one.
  defp unreadable?(name) do
    name
    |> String.to_charlist()
    |> Enum.any?(fn codepoint ->
      codepoint <= 0x1F or codepoint in 0x7F..0x9F or
        codepoint in 0x202A..0x202E or codepoint in 0x2066..0x2069
    end)
  end

  @doc """
  Checks whether a requested `redirect_uri` is registered in a CIMD document's
  `redirect_uris`.

  Non-loopback URIs must match exactly. For loopback URIs (`localhost`,
  `127.0.0.1`, `[::1]`) the port - and only the port - may differ, per
  [OAuth 2.1 §2.3.1](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-registration-requirements)
  and [RFC 8252 §7.3](https://www.rfc-editor.org/rfc/rfc8252.html#section-7.3):
  a native client binds an ephemeral port it cannot know ahead of time.

  Every other component must match exactly, so a registered loopback URI cannot
  be turned into a different endpoint by appending a query string. Scheme and
  host are case-insensitive (RFC 3986 sections 3.1 and 3.2.2), nothing else is.
  """
  @spec redirect_uri_registered?(String.t() | nil, [String.t()]) :: boolean()
  def redirect_uri_registered?(redirect_uri, registered) when is_binary(redirect_uri) do
    redirect_uri in registered or loopback_match?(redirect_uri, registered)
  end

  def redirect_uri_registered?(_redirect_uri, _registered), do: false

  defp loopback_match?(redirect_uri, registered) do
    uri = URI.parse(redirect_uri)

    loopback_host?(uri.host) and
      Enum.any?(registered, fn candidate ->
        registered_uri = URI.parse(candidate)

        loopback_host?(registered_uri.host) and equal_but_for_port?(registered_uri, uri)
      end)
  end

  # Case-folded because RFC 3986 section 3.2.2 makes the host case-insensitive,
  # so `LOCALHOST` names the same interface as `localhost`.
  defp loopback_host?(host), do: downcase(host) in ["localhost", "127.0.0.1", "::1"]

  defp equal_but_for_port?(%URI{} = a, %URI{} = b) do
    downcase(a.scheme) == downcase(b.scheme) and
      is_nil(a.userinfo) and
      a.userinfo == b.userinfo and
      downcase(a.host) == downcase(b.host) and
      a.path == b.path and
      a.query == b.query and
      a.fragment == b.fragment
  end

  defp downcase(nil), do: nil
  defp downcase(value), do: String.downcase(value)
end
