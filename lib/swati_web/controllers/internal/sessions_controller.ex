defmodule SwatiWeb.Internal.SessionsController do
  use SwatiWeb, :controller

  alias Swati.Sessions.Ingestion

  def events(conn, %{"session_id" => session_id, "events" => events}) when is_list(events) do
    _ = Ingestion.append_events(session_id, events)
    json(conn, %{status: "ok"})
  end

  def end_session(conn, %{"session_id" => session_id} = params) do
    case Ingestion.end_session(session_id, params) do
      {:ok, session} ->
        json(conn, %{session_id: session.id})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_changeset(changeset)
    end
  end

  def artifacts(conn, %{"session_id" => session_id} = params) do
    _ = Ingestion.set_artifacts(session_id, params)
    json(conn, %{session_id: session_id})
  end

  def timeline(conn, %{"session_id" => session_id, "timeline" => timeline})
      when is_map(timeline) do
    case Ingestion.set_timeline(session_id, timeline) do
      :ok ->
        json(conn, %{session_id: session_id})

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
