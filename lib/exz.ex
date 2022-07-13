defmodule Exz do
  defmacro exz(attrs,[do: {:__block__,_,z_blocks}]) do
    unless Process.whereis(__MODULE__) do
      {:ok,pid} = Exos.Proc.start_link("node --stack-size=65500 index.js",%{},[cd: '#{:code.priv_dir(:exz)}/js_dom/'], name: __MODULE__)
      Process.unlink(pid)
    end
    
    z_blocks = for {:z,_,[attrs|do_block]} <- z_blocks do
      %{sel: attrs[:sel], tag: attrs[:tag],
        attrs: attrs |> Enum.into(%{}) |> Map.drop([:sel,:tag]), 
        body: List.first(do_block)[:do] || ""}
    end
    
    case {attrs[:in],attrs[:sel]} do
      {file,sel} when is_binary(file) and is_binary(sel)->
        path = Path.join(Path.expand(Mix.Project.config[:exz_dir] || "."),file)
        path = String.replace_suffix(path,".html","") <> ".html"
        dom = GenServer.call(__MODULE__, {:parse_file, path, sel, Enum.map(z_blocks,& &1.sel)})
        ast = dom2ast(dom,z_blocks)
        #ast
        ast = quote do IO.chardata_to_string(unquote(ast)) end
        Macro.to_string(ast) |> IO.puts
        ast
    end
  end

  def dom2ast(bin,_z_blocks) when is_binary(bin) do bin end
  def dom2ast({tag,nil,attrs,children},z_blocks) do
    attrs = Enum.map(attrs, fn {k,v}-> "#{k}=\"#{v}\"" end)
    ["<#{tag} #{attrs}>",
      Enum.map(children,&dom2ast(&1,z_blocks)),
     "</#{tag}>"]
  end
  def dom2ast({tag,{zidx,matchidx},attrs,children},z_blocks) do
    %{tag: ztag, attrs: zattrs, body: ast} = Enum.at(z_blocks,zidx)
    ast = Macro.postwalk(ast,fn
      {:childrenZ,_,_}-> Enum.map(children,&dom2ast(&1,z_blocks))
      {:indexZ,_,_}-> matchidx
      other-> other
    end)
    attrs = Map.merge(attrs,zattrs) |> Enum.map(fn 
      {_,nil}-> []
      {k,v}-> 
        v = Macro.postwalk(v,fn
          {:indexZ,_,_}-> matchidx
          {id,_,_}=vast when is_atom(id)->
            case String.split(to_string(id),"Z") do
              [name,""]-> attrs[:"#{name}"]
              _other-> vast
            end
          other-> other
        end)
        quote do unquote(" #{k}=\"") <> unquote(v) <> "\"" end
    end)
    ["<#{ztag || tag} ",attrs,">",ast,"</#{ztag || tag}>"]
  end
end
