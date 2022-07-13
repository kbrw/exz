defmodule ExzTest do
  use ExUnit.Case
  doctest Exz
  import Exz

  def myfun do
    styles = ["red","blue"]
    exz in: "test", sel: "body", toto: totoZ <> "titi", tag: "mybody" do
      z sel: ".l3", style: nil, tag: "aaaa", tt: ttZ <> "cc" do "me" end
      z sel: ".l11", to: "mince" do
        """
        hello you
        <p>first childrenz</p>
        #{childrenZ}
        <p>second childrenz</p>
        <div>#{childrenZ}</div>
        <p>third childrenz</p>
        <div><a></a>#{childrenZ}</div>
        <p>fourth childrenz</p>
        <div>#{childrenZ}</div>
        """
      end
      z sel: ".l111 li", class: Enum.at(styles,indexZ) do
        "<span>#{childrenZ}</span>"
      end
    end
  end

  test "simple jsxz" do
    IO.puts myfun()
  end
end
