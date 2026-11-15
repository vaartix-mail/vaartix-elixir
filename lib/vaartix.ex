defmodule Vaartix do
  @moduledoc """
  The official Elixir client for [Vaartix](https://vaartix.com), the transactional email API built in India.

      client = Vaartix.client()   # reads VAARTIX_API_KEY
      {:ok, %{"id" => id}} =
        Vaartix.Emails.send(client, %{
          from: "Acme <orders@acme.in>",
          to: "priya@example.com",
          subject: "Your order is confirmed",
          html: "<p>Thanks for your order!</p>"
        })

  Every function returns `{:ok, result}` or `{:error, %Vaartix.Error{}}`. Results are the API's JSON
  as maps with string keys. Keys you pass can be snake_case atoms (`reply_to`, `scheduled_at`) or the
  API's camelCase.
  """

  @version Mix.Project.config()[:version]
  @default_base_url "https://api.vaartix.com"

  @doc false
  def version, do: @version

  @doc """
  Create a client. A nil `api_key` reads `VAARTIX_API_KEY`.

  Options: `:base_url`, `:receive_timeout` (ms, default 30_000), and `:req_options` passed to Req
  (for example `[plug: ...]` or `[adapter: ...]` in tests).
  """
  @spec client(String.t() | nil, keyword()) :: Vaartix.Client.t()
  def client(api_key \\ nil, opts \\ []) do
    key = api_key || System.get_env("VAARTIX_API_KEY")

    if key in [nil, ""] do
      raise ArgumentError, "Missing API key. Pass it to Vaartix.client/1 or set VAARTIX_API_KEY."
    end

    base = opts |> Keyword.get(:base_url, @default_base_url) |> String.trim_trailing("/")

    req =
      Req.new(
        base_url: base,
        auth: {:bearer, key},
        headers: [{"user-agent", "vaartix-elixir/#{@version}"}, {"accept", "application/json"}],
        receive_timeout: Keyword.get(opts, :receive_timeout, 30_000),
        retry: false,
        decode_body: false
      )
      |> Req.merge(Keyword.get(opts, :req_options, []))

    %Vaartix.Client{req: req}
  end
end
