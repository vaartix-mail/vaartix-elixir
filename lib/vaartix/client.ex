defmodule Vaartix.Client do
  @moduledoc "A configured client. Create it with `Vaartix.client/2`."
  @enforce_keys [:req]
  defstruct [:req]
  @type t :: %__MODULE__{req: Req.Request.t()}

  @key_names %{
    reply_to: "replyTo",
    scheduled_at: "scheduledAt",
    content_type: "contentType",
    content_id: "contentId",
    open_tracking: "openTracking",
    click_tracking: "clickTracking"
  }

  @doc false
  def to_api(%{} = map) when not is_struct(map) do
    for {k, v} <- map, not is_nil(v), into: %{} do
      {Map.get(@key_names, k, to_string(k)), to_api(v)}
    end
  end

  def to_api(list) when is_list(list), do: Enum.map(list, &to_api/1)
  def to_api(v), do: v

  @doc false
  def esc(id), do: URI.encode(to_string(id), &URI.char_unreserved?/1)

  @doc false
  def request(%__MODULE__{req: req}, method, path, body \\ nil, opts \\ []) do
    headers =
      case Keyword.get(opts, :idempotency_key) do
        nil -> []
        k -> [{"idempotency-key", k}]
      end

    req_opts = [method: method, url: path, headers: headers]
    req_opts = if body == nil, do: req_opts, else: Keyword.put(req_opts, :json, to_api(body))

    case Req.request(req, req_opts) do
      {:ok, %Req.Response{status: status, body: raw}} when status in 200..299 ->
        decode(raw, status)

      {:ok, %Req.Response{status: status, body: raw}} ->
        err =
          case Jason.decode(to_string(raw)) do
            {:ok, %{"error" => %{} = e}} -> e
            _ -> %{}
          end

        {:error,
         %Vaartix.Error{
           type: err["type"] || "api_error",
           message: err["message"] || "Request failed with status #{status}",
           status: status
         }}

      {:error, exception} ->
        {:error, %Vaartix.Error{type: "network_error", message: Exception.message(exception), status: nil}}
    end
  end

  defp decode(raw, status) do
    case to_string(raw) do
      "" ->
        {:ok, nil}

      text ->
        case Jason.decode(text) do
          {:ok, data} ->
            {:ok, data}

          {:error, _} ->
            {:error,
             %Vaartix.Error{type: "api_error", message: "Could not read the response", status: status}}
        end
    end
  end
end
