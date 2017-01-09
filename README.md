# Debounce

A process-based debouncer for Elixir.

Full documentation can be found at https://hexdocs.pm/debounce

## What is a debouncer?

A debouncer is responsible for calling a function with a delay, but if that
function is called multiple times within the delay period, the time is reset
and delay is counted again. In other words, the function will be called
after a delay period has elapsed from the last application.

Each time, the debounced function is called, a new task is started.

## Example

```elixir
iex> {:ok, pid} = Debounce.start_link({Kernel, :send, [self(), "Hello"]}, 100)
iex> Debounce.apply(pid)  # Schedules call in 100 ms
iex> :timer.sleep(50)
iex> Debounce.apply(pid)  # Resets timer back to 100 ms
iex> :timer.sleep(100)
iex> receive do msg -> msg end
"Hello"                   # Timer elapsed
iex> Debounce.apply(pid)  # Schedules call in 100 ms
iex> Debounce.cancel(pid) # Cancels scheduled call
:ok
```

## Installation

The package can be installed by adding `debounce` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [{:debounce, "~> 0.1.0"}]
end
```
