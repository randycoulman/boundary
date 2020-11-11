defmodule Mix.Tasks.Boundary.Visualize.Mods do
  @moduledoc false

  use Boundary, classify_to: Boundary.Mix
  use Mix.Task

  alias Boundary.Graph
  alias Boundary.Mix.Xref

  @impl Mix.Task
  def run(argv) do
    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Quiet)
    Mix.Task.run("compile")
    Mix.shell(previous_shell)

    Boundary.Mix.load_app()

    view = Boundary.view(Boundary.Mix.app_name())
    boundaries = Enum.map(argv, &Module.concat([&1]))

    state =
      for call <- Xref.calls(),
          boundary_from = Boundary.for_module(view, call.caller_module),
          not is_nil(boundary_from),
          boundary_from.name in boundaries,
          boundary_to = Boundary.for_module(view, call.callee_module),
          not is_nil(boundary_to),
          boundary_to.name in boundaries,
          reduce: %{main: Graph.new(""), subgraphs: %{}} do
        state ->
          state
          |> add_node(boundary_from.name, call.caller_module)
          |> add_node(boundary_to.name, call.callee_module)
          |> add_dependency(call.caller_module, call.callee_module)
      end

    Enum.reduce(Map.values(state.subgraphs), state.main, &Graph.add_subgraph(&2, &1))
    |> Graph.dot()
    |> Mix.shell().info()
  end

  defp add_node(state, subgraph_name, node) do
    subgraph =
      state.subgraphs
      |> Map.get_lazy(subgraph_name, fn -> Graph.new("Boundary #{inspect(subgraph_name)}") end)
      |> Graph.add_node(inspect(node), label: List.last(Module.split(node)))

    Map.update!(state, :subgraphs, &Map.put(&1, subgraph_name, subgraph))
  end

  defp add_dependency(state, caller, callee),
    do: Map.update!(state, :main, &Graph.add_dependency(&1, inspect(caller), inspect(callee)))
end
