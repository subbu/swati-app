defmodule Mix.Tasks.Swati.Harness.Check do
  use Mix.Task

  @shortdoc "Run fast, agent-friendly checks (format, compile, test, optional static analysis)."

  @moduledoc """
  Agent-first harness check for the Swati repository.

  Usage:
    mix swati.harness.check
    mix swati.harness.check --full
    mix swati.harness.check --no-test
    mix swati.harness.check --no-compile

  Notes:
  - For running tests, prefer MIX_ENV=test.
  - --full will try to run credo and dialyzer if those tasks exist in the project.
  """

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [full: :boolean, no_test: :boolean, no_compile: :boolean]
      )

    full? = opts[:full] || false
    no_test? = opts[:no_test] || false
    no_compile? = opts[:no_compile] || false

    Mix.shell().info("Swati harness check starting (env=#{Mix.env()})")

    run_mix("format", ["--check-formatted"])

    unless no_compile? do
      run_mix("compile", ["--warnings-as-errors"])
    end

    unless no_test? do
      if Mix.env() != :test do
        Mix.shell().info("Note: mix test is usually run with MIX_ENV=test.")
      end

      run_mix("test", [])
    end

    if full? do
      maybe_run_mix("credo", ["--strict"])
      maybe_run_mix("dialyzer", [])
    end

    Mix.shell().info("Swati harness check complete.")
  end

  defp run_mix(task, args) do
    Mix.shell().info("→ mix #{task} #{Enum.join(args, " ")}")
    Mix.Task.reenable(task)
    Mix.Task.run(task, args)
  end

  defp maybe_run_mix(task, args) do
    case Mix.Task.get(task) do
      nil ->
        Mix.shell().info("↷ skipping mix #{task} (task not available)")

      _ ->
        run_mix(task, args)
    end
  end
end
