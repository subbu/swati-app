defmodule Swati.Sessions.SessionToolCall do
  use Swati.DbSchema

  schema "session_tool_calls" do
    field :name, :string
    field :status, :string
    field :start_ms, :integer
    field :end_ms, :integer
    field :latency_ms, :integer
    field :args, :map
    field :response_summary, :string
    field :mcp_endpoint, :string
    field :mcp_session_id, :string

    belongs_to :session, Swati.Sessions.Session

    timestamps()
  end

  def changeset(tool_call, attrs) do
    tool_call
    |> cast(attrs, [
      :session_id,
      :name,
      :status,
      :start_ms,
      :end_ms,
      :latency_ms,
      :args,
      :response_summary,
      :mcp_endpoint,
      :mcp_session_id
    ])
    |> validate_required([:session_id, :name, :status, :start_ms, :end_ms])
  end
end
