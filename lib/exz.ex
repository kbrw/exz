defmodule Exz do
  defmacro exz(attrs,[do: exz_do] \\ [do: quote do childrenZ end]) do
    case Exos.Proc.start_link("node --stack-size=65500 index.js",%{},[cd: '#{:code.priv_dir(:exz)}/js_dom/'], name: __MODULE__) do
      {:error, {:already_started,_}}-> :ok # ensure JS HTML parser server exists, do nothing if it is
      {:ok,pid}-> Process.unlink(pid) # do not need to handle lifetime of HTML parser server as it exists only during build (macro exec)
    end
    
    z_blocks_ast = case exz_do do # get [z()] transfo AST
      {:__block__,_,[{:z,_,_}|_]=blocks}-> blocks # if called as esz do z() z() end
      {:z,_,_}=ast-> [ast] # if called as esz do z() end
      _-> :no_z_transfos # no z() transformation !
    end
    {rootbody,z_blocks} = case z_blocks_ast do
      :no_z_transfos-> {exz_do,[]} # if no z() transfo : `exz do BODY end`, then BODY replaces matching exz children
      _-> # there are `z sel: ...` transformers
        blocks = for {:z,_,[attrs|do_block]} <- z_blocks_ast do
          %{sel: attrs[:sel], tag: attrs[:tag], replace: attrs[:replace] == true,
            attrs: attrs |> Enum.into(%{}) |> Map.drop([:sel,:tag,:replace]), # z(attrs) sel: and tag: attrs are reserved EXS and not html attr
            body: List.first(do_block)[:do] || quote do childrenZ end} # z(sel: "c") body default is to copy all children (childrenZ)
        end
        {quote do childrenZ end,blocks}
    end
    
    tpl_q = case {attrs[:in],attrs[:sel]} do
      {file,sel} when is_binary(file) and is_binary(sel)->
        path = Path.join(Path.expand(Mix.Project.config[:exz_dir] || "."),file)
        path = String.replace_suffix(path,".html","") <> ".html"
        {:ok,dom} = GenServer.call(__MODULE__, {:parse_file, path, sel, Enum.map(z_blocks,& &1.sel)})
        zroot = %{tag: attrs[:tag], sel: attrs[:sel], replace: false,
                 attrs: attrs |> Enum.into(%{}) |> Map.drop([:sel,:tag,:in,:debug]),
                 body: rootbody}
        ast = dom2ast(put_elem(dom,1,{-1,0}),[zroot|z_blocks])
        quote do IO.chardata_to_string(unquote(ast)) end
    end
    if attrs[:debug] do IO.puts(["debug exz : expanding to :\n",tpl_q |> Macro.to_string |> Code.format_string!]) end
    tpl_q
  end

  def dom2ast(bin,_z_blocks) when is_binary(bin) do bin end
  @void_elems ~w"area base br col embed hr img input link meta source track wbr"
  def dom2ast({tag,nil,attrs,[]},_z_blocks) when tag in @void_elems do
    attrs = Enum.map(attrs, fn {k,v}-> "#{k}=\"#{v}\"" end)
    if tag in @void_elems do
      "<#{tag} #{attrs}>"
    else
      "<#{tag} #{attrs}></#{tag}>"
    end
  end
  def dom2ast({tag,nil,attrs,children},z_blocks) do
    attrs = Enum.map(attrs, fn {k,v}-> "#{k}=\"#{v}\"" end)
    ["<#{tag} #{attrs}>",
      Enum.map(children,&dom2ast(&1,z_blocks)),
     "</#{tag}>"]
  end
  def dom2ast({tag,{zidx,matchidx},attrs,children},z_blocks) do
    %{tag: ztag, attrs: zattrs, body: ast, replace: replace?} = Enum.at(z_blocks,zidx+1)
    ast = ast_zmapping(ast,matchidx,attrs,children,z_blocks)
    attrs = Map.merge(attrs,zattrs) |> Enum.map(fn 
      {_,nil}-> []
      {k,v}-> 
        v = ast_zmapping(v,matchidx,attrs,children,z_blocks)
        quote do unquote(" #{k}=\"") <> unquote(v) <> "\"" end
    end)
    use_tag = ztag || tag
    cond do
      replace? == true-> ast
      ast in ["",[]] and use_tag in @void_elems->
        ["<#{use_tag}",attrs,">"]
      true->
        ["<#{use_tag}",attrs,">",ast,"</#{use_tag}>"]
    end
  end

  def ast_zmapping(ast, matchidx, attrs, children, z_blocks) do
    {ast,_} = Macro.prewalk(ast, :no_subz, fn
      {atom,_,_}=d, _ when atom in [:z,:exz]-> {d,:subz}
      {:indexZ,_,_}, :no_subz-> {matchidx,:no_subz}
      {:childrenZ,_,_}, :no_subz-> {Enum.map(children,&dom2ast(&1,z_blocks)),:no_subz}
      {id,_,_}=id_ast, :no_subz when is_atom(id)->
        case String.split(to_string(id),"Z") do
          [name,""]-> {attrs[:"#{name}"],:no_subz}
          _other-> {id_ast,:no_subz}
        end
      other, acc-> {other,acc}
    end)
    ast
  end
end
