defmodule Debounce.Application do
  @moduledoc false

  use Application

  import Supervisor.Spec

  def start(_, _) do
    children = [
      worker(Task.Supervisor, [[name: Debounce.Supervisor]])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
