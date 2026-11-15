defmodule Vaartix.Webhook do
  @moduledoc """
  Check that a webhook request really came from Vaartix (Standard Webhooks spec).

      # Phoenix: read the raw body first (see the README), then:
      case Vaartix.Webhook.verify(raw_body, conn.req_headers, System.fetch_env!("VAARTIX_WEBHOOK_SECRET")) do
        {:ok, %{"type" => "email.bounced", "data" => %{"details" => details}}} ->
          details["diagnosticCode"]   # the receiving server's reply
        {:ok, _event} -> :ok
        {:error, reason} -> reason
      end
  """

  @events ~w(email.sent email.delivered email.delivery_delayed email.bounced email.complained email.rejected
             email.rendering_failure email.suppressed email.opened email.clicked)

  @doc "Every webhook event type."
  def events, do: @events

  @doc """
  Verify a request and return `{:ok, payload}` or `{:error, reason}`. `headers` is a list of
  `{name, value}` tuples (like `conn.req_headers`) or a map; names are matched case-insensitively.
  Options: `:tolerance` in seconds (default 300), `:now` (Unix seconds).
  """
  @spec verify(binary(), list() | map(), String.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def verify(payload, headers, secret, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance, 300)
    now = Keyword.get_lazy(opts, :now, fn -> System.system_time(:second) end)

    get = fn name ->
      Enum.find_value(headers, fn {k, v} -> if String.downcase(to_string(k)) == name, do: v end)
    end

    with {id, ts, sigs} when is_binary(id) and is_binary(ts) and is_binary(sigs) <-
           {get.("webhook-id"), get.("webhook-timestamp"), get.("webhook-signature")},
         {sent, ""} <- Integer.parse(ts),
         true <-
           abs(now - sent) <= tolerance || {:error, "The webhook timestamp is too old or in the future."},
         {:ok, key} <- secret_key(secret),
         expected = :crypto.mac(:hmac, :sha256, key, "#{id}.#{ts}.#{payload}"),
         true <- valid?(sigs, expected) || {:error, "The webhook signature does not match."},
         {:ok, decoded} <- Jason.decode(payload) |> ok_or("The body is not valid JSON.") do
      {:ok, decoded}
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      {nil, _, _} -> {:error, "Missing webhook-id, webhook-timestamp or webhook-signature header."}
      {_, nil, _} -> {:error, "Missing webhook-id, webhook-timestamp or webhook-signature header."}
      {_, _, nil} -> {:error, "Missing webhook-id, webhook-timestamp or webhook-signature header."}
      _ -> {:error, "The webhook timestamp is too old or in the future."}
    end
  end

  # The header can hold several space-separated signatures, e.g. while a secret is rotated.
  defp valid?(sigs, expected) do
    sigs
    |> String.split(" ", trim: true)
    |> Enum.any?(fn entry ->
      case String.split(entry, ",", parts: 2) do
        ["v1", sig] ->
          case Base.decode64(sig) do
            {:ok, given} when byte_size(given) == byte_size(expected) -> :crypto.hash_equals(given, expected)
            _ -> false
          end

        _ ->
          false
      end
    end)
  end

  defp secret_key("whsec_" <> encoded), do: Base.decode64(encoded) |> ok_or("The secret is not valid base64.")
  defp secret_key(_), do: {:error, "The secret should start with whsec_."}

  defp ok_or({:ok, v}, _), do: {:ok, v}
  defp ok_or(_, reason), do: {:error, reason}
end
