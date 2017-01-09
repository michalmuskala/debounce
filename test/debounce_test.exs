defmodule DebounceTest do
  use ExUnit.Case
  doctest Debounce

  test "single apply" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    refute_receive :done, 15
    assert :ok = Debounce.apply(pid)
    assert_receive :done, 15
    refute_receive :done
  end

  test "multiple apply within timeout" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    refute_receive :done, 5
    assert :ok = Debounce.apply(pid)
    assert_receive :done, 15
    refute_receive :done
  end

  test "multiple apply after timeout" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    assert_receive :done, 15
    assert :ok = Debounce.apply(pid)
    assert_receive :done, 15
    refute_receive :done
  end

  test "cancel without apply" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.cancel(pid)
  end

  test "cancel after apply" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    assert :ok = Debounce.cancel(pid)
    refute_receive :done
  end

  test "change_function does not affect current timer" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    assert :ok = Debounce.change_function(pid, {:erlang, :send, [self(), :new]})
    assert_receive :done, 15
  end

  test "change_function affects future timers" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.change_function(pid, {:erlang, :send, [self(), :new]})
    assert :ok = Debounce.apply(pid)
    assert_receive :new, 15
  end

  test "change_timeout does not affect current timer" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    assert :ok = Debounce.change_timeout(pid, 100)
    assert_receive :done, 15
  end

  test "change_timeout affects future timers" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.change_timeout(pid, 100)
    assert :ok = Debounce.apply(pid)
    refute_receive :done, 15
    assert_receive :done, 100
  end
end
