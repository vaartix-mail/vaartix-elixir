defmodule Vaartix.Emails do
  @moduledoc "Send and read emails."
  alias Vaartix.Client

  @doc """
  Send one email. Set `html` or `text` (or both). `tracking: %{opens: true, clicks: false}` overrides
  the domain's defaults. Pass `idempotency_key: "..."` to make retries safe for 24 hours.
  """
  def send(client, email, opts \\ []), do: Client.request(client, :post, "/emails", email, opts)

  @doc "One email with its events. Needs a full-access key."
  def get(client, id), do: Client.request(client, :get, "/emails/#{Client.esc(id)}")

  @doc "Recent emails, newest first. Options: `:limit` (1–100), `:before` (an email ID). Needs a full-access key."
  def list(client, opts \\ []) do
    query = opts |> Keyword.take([:limit, :before]) |> URI.encode_query()
    Client.request(client, :get, if(query == "", do: "/emails", else: "/emails?" <> query))
  end

  @doc "Cancel a scheduled email before it is sent. Needs a full-access key."
  def cancel(client, id), do: Client.request(client, :post, "/emails/#{Client.esc(id)}/cancel")
end

defmodule Vaartix.Batch do
  @moduledoc "Send many emails in one request."
  alias Vaartix.Client

  @doc "Up to 100 emails (no attachments or scheduling). All or nothing. Returns the list of `%{\"id\" => ...}`."
  def send(client, emails) when is_list(emails) do
    with {:ok, %{"data" => data}} <- Client.request(client, :post, "/emails/batch", emails), do: {:ok, data}
  end
end

defmodule Vaartix.Domains do
  @moduledoc "Sending domains. Changes need a full-access key from an owner or admin."
  alias Vaartix.Client

  @doc "Change a domain's default open and click tracking: `%{open_tracking: true}`. Keys left out keep their value."
  def update(client, id, changes), do: Client.request(client, :patch, "/domains/#{Client.esc(id)}", changes)
end

defmodule Vaartix.Webhooks do
  @moduledoc "Webhook endpoints. Needs a full-access key. To check incoming requests, see `Vaartix.Webhook.verify/4`."
  alias Vaartix.Client

  @doc "Create an endpoint: `%{url: ..., events: [...]}`. The response includes the signing secret, shown only once."
  def create(client, params), do: Client.request(client, :post, "/webhooks", params)

  @doc "All endpoints."
  def list(client) do
    with {:ok, %{"data" => data}} <- Client.request(client, :get, "/webhooks"), do: {:ok, data}
  end

  @doc "One endpoint."
  def get(client, id), do: Client.request(client, :get, "/webhooks/#{Client.esc(id)}")

  @doc "Change the URL or events, or turn the endpoint off (`status: \"disabled\"`) and on."
  def update(client, id, changes), do: Client.request(client, :patch, "/webhooks/#{Client.esc(id)}", changes)

  @doc "Delete an endpoint."
  def remove(client, id), do: Client.request(client, :delete, "/webhooks/#{Client.esc(id)}")

  @doc "Replace the signing secret. The old one stops working immediately."
  def rotate_secret(client, id),
    do: Client.request(client, :post, "/webhooks/#{Client.esc(id)}/rotate-secret")

  @doc "Recent deliveries, newest first. Option: `:limit`."
  def deliveries(client, id, opts \\ []) do
    q =
      case opts[:limit] do
        nil -> ""
        l when is_integer(l) -> "?limit=#{l}"
      end

    with {:ok, %{"data" => data}} <-
           Client.request(client, :get, "/webhooks/#{Client.esc(id)}/deliveries#{q}"),
         do: {:ok, data}
  end

  @doc "Send a delivery again, with the same webhook-id."
  def retry_delivery(client, id, delivery_id),
    do:
      Client.request(client, :post, "/webhooks/#{Client.esc(id)}/deliveries/#{Client.esc(delivery_id)}/retry")
end
