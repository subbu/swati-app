defmodule SwatiWeb.Internal.CallsController do
  use SwatiWeb, :controller

  alias Swati.Calls.Ingestion

  def start(conn, params) do
    case Ingestion.start(params) do
      {:ok, call} ->
        json(conn, %{call_id: call.id})

      {:error, :phone_number_missing_agent} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "phone_number_missing_agent"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_changeset(changeset)
    end
  end

  def events(conn, %{"call_id" => call_id, "events" => events}) when is_list(events) do
    _ = Ingestion.append_events(call_id, events)
    json(conn, %{status: "ok"})
  end

  def end_call(conn, %{"call_id" => call_id} = params) do
    case Ingestion.end_call(call_id, params) do
      {:ok, call} ->
        json(conn, %{call_id: call.id})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_changeset(changeset)
    end
  end

  def artifacts(conn, %{"call_id" => call_id} = params) do
    case Ingestion.set_artifacts(call_id, params) do
      {:ok, call} ->
        json(conn, %{call_id: call.id})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_changeset(changeset)
    end
  end

  def timeline(conn, %{"call_id" => call_id, "timeline" => timeline})
      when is_map(timeline) do
    case Ingestion.set_timeline(call_id, timeline) do
      :ok ->
        json(conn, %{call_id: call_id})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  defp render_changeset(conn, %Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
        SwatiWeb.CoreComponents.translate_error({message, opts})
      end)

    json(conn, %{error: errors})
  end
end
