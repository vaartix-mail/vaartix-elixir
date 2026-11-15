defmodule Vaartix.Error do
  @moduledoc """
  The API answered with an error, or the request could not be made. `type` is the API's error type
  (e.g. `"validation_error"`), or `"network_error"` with `status: nil` when no response was received.
  """
  defexception [:type, :message, :status]
  @type t :: %__MODULE__{type: String.t(), message: String.t(), status: pos_integer() | nil}
end
