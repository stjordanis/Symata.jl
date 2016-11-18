## The code below `Part` this file should be used to replace the guts of Part
## For setting and getting with Part, in Table, ...

## In other words: Part uses older part setting code. Other functions that get and
## set parts use newer code.

### Part

@sjdoc Part """
    Part(expr,n) or expr[n]

returns the `n`th element of expression `expr`.

    Part(expr,n1,n2,...) or expr[n1,n2,...]

return the subexpression at index `[n1,n2,...]`.

The same can be achieved less efficiently with `expr[n1][n2]...`.

    expr[n] = val

set the `n`th part of `expr` to `val`. `n` and `val` are evaluated
normally. `expr` is evaluated once.

`n` less than zero counts backward from the end of the expression or subexpression.

`expr[n]` also returns the `n`th element of instances of several
Julia types such as `Array`, or the element with key `n` for `Dict`'s.
"""

# Get part of expression. Julia :ref is mapped to :Part
# a[i] parses to Part(a,i), and a[i][j] to Part(Part(a,i),j)
# a[i,j] parses to Part(a,i,j).

@mkapprule Part

@doap function Part(texpr,tinds...)
    for j in 1:length(tinds)
        texpr = get_part_one_ind(texpr,tinds[j])
    end
    return texpr
end

function get_part_one_ind{V<:Union{Mxpr,Array}}(texpr::V,ind::Integer)
    ind = ind < 0 ? length(texpr)+ind+1 : ind
    texpr = ind == 0 ? mhead(texpr) : texpr[ind]
    return texpr
end

get_part_one_ind(texpr::Dict,tind) = texpr[tind]  # Part 0 can't return "Dict" because it could be a key.
get_part_one_ind(texpr::Tuple,tind) = texpr[tind]


### Span

@sjdoc Span """
    Span(a,b) or a:b

represents elements `a` through `b`.

    Span(a,b,c) or a:b:c 

represents elements `a` through `b` in steps of `c`.

`expr[a:b]` returns elements a through `b` of expr, with the same head as `expr`.
"""
function get_part_one_ind(texpr::Mxpr,tind::Mxpr{:Span})
    spanargs = margs(tind)
    lsp = length(spanargs)
    if lsp == 2
        nargs = view(margs(texpr),spanargs[1]:spanargs[2]) # need function to do this translation
    elseif lsp == 3
        nargs = view(margs(texpr),spanargs[1]:spanargs[3]:spanargs[2])
    end
    texpr = mxpr(mhead(texpr),nargs...) # we need splice to copy Int Array to Any Array
    return texpr
end

### Position

@sjdoc Position """
    Position(expr,x)

return a list of part specifications (indices) of positions in
`expr` at which `x` occurs.
"""
@mkapprule Position
@doap Position(expr,subx) = tolistoflists(find_positions(expr,subx))

@curry_second Position

"""
    find_positions(ex,subx)

return a list of part indices at which subexpression `subx` occurs in expression `ex`.
"""
function find_positions(ex,subx)
    posns = Array(Array{Int,1},0)
    lev = Array(Int,100)
    clev::Int = 1
    lev[clev] = 0
    capt = capturealloc()
    psubx = patterntoBlank(subx)
    _find_positions(ex,psubx,lev,posns,clev,capt)
    return posns
end

# TODO: split out literal pattern code: This routine will be the main routine for
# finding positions, inlcuding when we know that the pattern is literal.
function _find_positions(ex::Mxpr,psubx,lev,posns,clev,capt)
    if clev > length(lev) push!(lev,0) end
    args = margs(ex)
    @inbounds for i in 1:length(args)
        lev[clev] = i
        _find_positions(args[i],psubx,lev,posns,clev+1,capt)
    end
    (gotmatch, capt) = match_and_capt(mhead(ex),psubx,capt)
    if gotmatch
#    if mhead(ex) == subx      # Use this for literal pattern
        lev[clev] = 0
        nlev = copy(lev)
        push!(posns,view(nlev,1:clev))
    end
    (gotmatch, capt) = match_and_capt(ex,psubx,capt)
    if gotmatch
#    if ex == subx
        nlev = copy(lev)
        push!(posns,view(nlev,1:clev-1))
    end
end

function _find_positions(ex,psubx,lev,posns,clev,capt)
    (gotmatch, capt) = match_and_capt(ex,psubx,capt)
    if gotmatch
#    if ex == subx
        nlev = copy(lev)
        push!(posns,view(nlev,1:clev-1))
    end
end


#### getpart

# TODO: implement :All in expressions like a[All,2]

"""
     getpart(mx::Mxpr,ind1::Integer,ind2::Integer,...)

return part of expression `mx`. `ind1,...` indices into `mx`.
An index value `0` refers to the head of `mx` or a subexpression, that is the part returned by `mhead`.
Index values greater than `0` refer to elements.

Note that `0` only makes sense as the last index.

Negative indices are not supported here.
"""
getpart(mx::Mxpr,ind) = (ind == 0 ? mhead(mx) : margs(mx)[ind])
getpart(mx::Mxpr, ind1, ind2) = getpart(getpart(mx,ind1),ind2)
getpart(mx::Mxpr, ind1, ind2, inds...) = getpart(getpart(getpart(mx,ind1),ind2), inds...)

# This gives error with a single index. Why ?
Base.getindex(mx::Mxpr, inds...) = getpart(mx,inds...)

#### setpart

"""
    setpart!(mx::Mxpr,val,inds...)

set the part of `mx` indexed by `inds` to `val`.

The last index equal to zero means the head of the subexpression specified by the previous indices.
Because most heads are effectively immutable, we must replace the final subexpression in this case.
"""
function setpart!(mx::Mxpr,val,inds...)
    if length(inds) == 0
        return mxpr(val,margs(mx))
    elseif length(inds) == 1
        if inds[1] == 0
            mx = mxpr(val,margs(mx)...)
            #            symprintln("new ", mx)
            # Function application is very slow if this branch is taken.
            return mx
#            symerror("Can't set head to $val. Not implemented")
#            newhead = val  ## Not working
        else
            margs(mx)[inds[1]] = val
        end
    elseif inds[end] == 0
        ninds = inds[1:end-2]
        if length(ninds) == 0
            symerror("Not implemented getting no part of $mx")
        end
        ex = getpart(mx, ninds...)
        ex1 = margs(ex)[inds[end-1]]
        margs(ex)[inds[end-1]] = mxpr(val, margs(ex1))
    else
        ex = getpart(mx, inds[1:end-1]...)
        margs(ex)[inds[end]] = val
    end
    mx
end

Base.setindex!(mx::Mxpr, val, inds...) = setpart!(mx,val,inds...)

#### localize variable

"""
    maybe_localize_variable(var::Symbol,expr)

If `var` is unbound (that is, evaluates to itself), return `(var,expr)`.
If `var` is bound, return `(var1,expr1)`, where `var1` is a new symbol (from `gensym`)
and `expr1` is a copy of `expr` with `var` replaced everywhere by `var1`.
"""
function maybe_localize_variable(var,expr::Mxpr)
    isbound(var) || return (var,expr)
    localize_variable(var,expr)
end

"""
    localize_variable(var::Symbol,expr)

return `(var1,expr1)`, where `var1` is a new symbol (from `gensym`)
and `expr1` is a copy of `expr` with `var` replaced everywhere by `var1`.
"""
function localize_variable(var,expr::Mxpr)
    sym = get_localized_symbol(var)  # not really necessary that named contains var
    positions = find_positions(expr,var)
    nexpr = deepcopy(expr)
    for pos in positions
       nexpr = setpart!(nexpr, sym, pos...)
    end
    (sym, nexpr)
end

function localize_variable(var,expr::SJSym)
    sym = get_localized_symbol(var)
    var == expr && return (sym,sym)
    return (sym, expr)
end

localize_variable(var,expr) = (get_localized_symbol(var), expr)

function localize_variables(vars::Array,expr::Mxpr)
    syms = map(get_localized_symbol, vars)
    nexpr = deepcopy(expr)
    for (sym,var) in zip(syms,vars)
        positions = find_positions(expr,var)
        for pos in positions
            setpart!(nexpr, sym, pos...)
        end
    end
    (syms, nexpr)
end

function localize_variables(vars::Array,expr::SJSym)
    syms = map(get_localized_symbol, vars)
    for (sym,var) in zip(syms,vars)
        var == expr && return (syms,sym)
    end
    return (syms, expr)
end

localize_variables(vars::Array,expr) = (map(get_localized_symbol, vars), expr)

### Take

@sjdoc Take """
    Take(expr,n)

returns `expr` keeping only the first `n` arguments.

    Take(expr,-n)

returns `expr` dropping all but the last `n` arguments.

    Take(expr,[n])

returns `expr` keeping only the `n`th arguments.

    Take(expr,[m,n])

returns `expr` keeping only the `m`th through `n`th arguments.

    Take(expr,[m,n,s])

returns `expr` keeping only the `m`th through `n`th arguments, with step `s`.

    Take(expr,spec1,spec2,...)

apply `spec1` at level `1`, `spec2` at level `2`...
"""
@mkapprule Take
@doap Take(x::Mxpr, rawspecs...) = take(x,map(sequencespec, rawspecs)...)
take(x, onespec, specs...) = mxpr(mhead(x),map(t -> take(t,specs...), margs(take(x,onespec)))...)
take(x,spec::SequenceN)     = mxpr(mhead(x), margs(x)[spec.n>=0?(1:spec.n):(length(x)+spec.n+1:end)]...)
take(x,spec::SequenceUpToN) = mxpr(mhead(x), margs(x)[1:min(spec.n,length(x))]...)
take(x,spec::SequenceNOnly) = mxpr(mhead(x), margs(x)[posnegi(x,spec.n)])
take(x,spec::SequenceMN)    = mxpr(mhead(x), margs(x)[posnegi(x,spec.m):posnegi(x,spec.n)]...)
take(x,spec::SequenceMNS)   = mxpr(mhead(x), margs(x)[posnegi(x,spec.m):spec.s:posnegi(x,spec.n)]...)
take(x,spec::SequenceNone)  = mxpr(mhead(x))
take(x,spec::SequenceAll)   = mxpr(mhead(x), margs(x)...)

### Drop

# With a little work, we could raise an error if the user tries to drop more elements
# than exists. In fact, the behavior is as if we always use UpTo.
@sjdoc Drop """
    Drop(expr,n)
    Drop(expr,-n)
    Drop(expr,[m,n])

!!! note
    `Drop(expr,UpTo(n))` is not necessary because `Drop(expr,n)` already gives the
    desired behavior.
"""

@mkapprule Drop
@doap Drop(x::Mxpr, rawspecs...) = drop(x,map(sequencespec, rawspecs)...)
drop(x, onespec, specs...) = mxpr(mhead(x),map(t -> drop(t,specs...), margs(drop(x,onespec)))...)
drop(x,spec::SequenceN) = mxpr(mhead(x), margs(x)[spec.n>0?(((spec.n)+1):end):(1:length(x)+spec.n)]...)
drop(x,spec::SequenceUpToN) = drop(x,SequenceN(spec.n))

function drop(x,spec::SequenceNOnly)
    n = posnegi(x,spec.n)
    ma = margs(x)
    mxpr(mhead(x), ma[1:n-1]..., ma[n+1:end]...)
end

function drop(x,spec::SequenceMN)
    m = posnegi(x,spec.m)
    n = posnegi(x,spec.n)
    ma = margs(x)
    mxpr(mhead(x), ma[1:m-1]..., ma[n+1:end]...)
end


### Extract

@sjdoc Extract """
    Extract(expr, list)

returns the subexpression specified by `list`.


    Extract(expr, [list1, list2, ...])

returns a list of subexpressions.

    Extract(expr, [list1, list2, ...], h)

wraps each subexpression with head `h`.

    Extract(list)

operator form of `Extract`.

`list` is a part specification as returned by `Part`.
"""
@mkapprule Extract

@doap function Extract(expr, p::List)
    isa(p[1],Integer) && return expr[margs(p)...]
    ! isa(p[1],List) && symerror("Exract: Bad part specification ", p)
    nargs = newargs(length(p))
    for i in 1:length(p)
        nargs[i] = expr[margs(p[i])...]
    end
    return MList(nargs)
end

@doap function Extract(expr, p::List, h)
    isa(p[1],Integer) && return mxpr(h,expr[margs(p)...])
    ! isa(p[1],List) && symerror("Exract: Bad part specification ", p)
    nargs = newargs(length(p))
    for i in 1:length(p)
        nargs[i] = mxpr(h,expr[margs(p[i])...])
    end
    return MList(nargs)
end

@curry_last Extract
