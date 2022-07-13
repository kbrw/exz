defmodule Exz do
  defmacro exz(attrs,[do: exz_do] \\ [do: quote do childrenZ end]) do
    unless Process.whereis(__MODULE__) do
      {:ok,pid} = Exos.Proc.start_link("node --stack-size=65500 index.js",%{},[cd: '#{:code.priv_dir(:exz)}/js_dom/'], name: __MODULE__)
      Process.unlink(pid)
    end
    
    z_blocks_ast = case exz_do do
      {:__block__,_,[{:z,_,_}|_]=blocks}-> blocks
      {:z,_,_}=ast-> [ast]
      _-> []
    end
    {rootbody,z_blocks} = case z_blocks_ast do
      []-> {exz_do,[]}
      _->
        blocks = for {:z,_,[attrs|do_block]} <- z_blocks_ast do
          %{sel: attrs[:sel], tag: attrs[:tag],
            attrs: attrs |> Enum.into(%{}) |> Map.drop([:sel,:tag]), 
            body: List.first(do_block)[:do] || quote do childrenZ end}
        end
        {quote do childrenZ end,blocks}
    end
    
    case {attrs[:in],attrs[:sel]} do
      {file,sel} when is_binary(file) and is_binary(sel)->
        path = Path.join(Path.expand(Mix.Project.config[:exz_dir] || "."),file)
        path = String.replace_suffix(path,".html","") <> ".html"
        dom = GenServer.call(__MODULE__, {:parse_file, path, sel, Enum.map(z_blocks,& &1.sel)})
        zroot = %{tag: attrs[:tag], sel: attrs[:sel],
                 attrs: attrs |> Enum.into(%{}) |> Map.drop([:sel,:tag,:in]),
                 body: rootbody}
        ast = dom2ast(put_elem(dom,1,{-1,0}),[zroot|z_blocks])
        quote do IO.chardata_to_string(unquote(ast)) end
    end
  end

  def dom2ast(bin,_z_blocks) when is_binary(bin) do bin end
  def dom2ast({tag,nil,attrs,[]},_z_blocks) do
    attrs = Enum.map(attrs, fn {k,v}-> "#{k}=\"#{v}\"" end)
    "<#{tag} #{attrs}/>"
  end
  def dom2ast({tag,nil,attrs,children},z_blocks) do
    attrs = Enum.map(attrs, fn {k,v}-> "#{k}=\"#{v}\"" end)
    ["<#{tag} #{attrs}>",
      Enum.map(children,&dom2ast(&1,z_blocks)),
     "</#{tag}>"]
  end
  def dom2ast({tag,{zidx,matchidx},attrs,children},z_blocks) do
    %{tag: ztag, attrs: zattrs, body: ast} = Enum.at(z_blocks,zidx+1)
    ast = ast_zmapping(ast,matchidx,attrs,children,z_blocks)
    attrs = Map.merge(attrs,zattrs) |> Enum.map(fn 
      {_,nil}-> []
      {k,v}-> 
        v = ast_zmapping(v,matchidx,attrs,children,z_blocks)
        quote do unquote(" #{k}=\"") <> unquote(v) <> "\"" end
    end)
    if ast not in ["",[]] do 
      ["<#{ztag || tag}",attrs,">",ast,"</#{ztag || tag}>"]
    else
      ["<#{ztag || tag}",attrs,"/>"]
    end
  end

  def ast_zmapping(ast, matchidx, attrs, children, z_blocks) do
    Macro.postwalk(ast,fn
      {:indexZ,_,_}-> matchidx
      {:childrenZ,_,_}-> Enum.map(children,&dom2ast(&1,z_blocks))
      {id,_,_}=id_ast when is_atom(id)->
        case String.split(to_string(id),"Z") do
          [name,""]-> attrs[:"#{name}"]
          _other-> id_ast
        end
      other-> other
    end)
  end
end
