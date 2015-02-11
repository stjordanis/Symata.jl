# Not super-fast.

@sjdoc For "
For(start,test,incr,body) is a for loop. Eg. For(i=1,i<=3, i = i + 1 , Println(i))
"

function apprules(mx::Mxpr{:For})
    (start,test,incr)= (mx[1],mx[2],mx[3])
    body = nothing
    if isdefined(margs(mx),4)
        body = mx[4]
    end
    doeval(start)
    while doeval(test)
        doeval(body)
        doeval(incr)
    end
end

@sjdoc If "
If(test,tbranch,fbranch) evaluates test and if the result is true, evaluates tbranch, otherwise fbranch
"

function apprules(mx::Mxpr{:If})
    (test,tbranch)= (mx[1],mx[2])
    fbranch = false
    if length(mx) == 3
        fbranch = mx[3]
    end
    tres = doeval(test) == true
    tres ? doeval(tbranch) : doeval(fbranch)
end

@sjdoc While "
While(test,body) evaluates test then body in a loop until test does not return true.
"

function apprules(mx::Mxpr{:While})
    (test,body)= (mx[1],mx[2])
    while doeval(test) == true
        doeval(body)
    end
end

@sjdoc Do "
Do(expr,[imax]) evaluates expr imax times.
Do(expr,[i,imax]) evaluates expr imax times with i localized taking values from 1 through
  imax in increments of 1.
Do(expr,[i,imin,imax]) evaluates expr with i taking values from imin to imax with increment 1.
  imin and imax may be symbolic.
"

function apprules(mx::Mxpr{:Do})
    expr = mx[1]
    iter = make_sjiter(mx[2])
    do_doloop(expr,iter)
end

function do_doloop(expr,iter::SJIter1)
    do_doloop_kern(expr,iter.imax)
end

function do_doloop_kern1(expr,imax)
    start = one(imax)
    for i in start:imax
        doeval(expr)
    end
end

function do_doloop(expr,iter::SJIter2)
    isym = gensym(string(iter.i))
    ex = replsym(deepcopy(expr),iter.i,isym)
    for i in 1:iter.imax  # mma makes i an Int no matter the type of iter.imax
        setsymval(isym,i)
        doeval(ex)
    end
end

function do_doloop{T<:Real,V<:Real}(expr,iter::SJIter3{T,V})
    isym = gensym(string(iter.i))
    ex = replsym(deepcopy(expr),iter.i,isym)
    for i in iter.imin:iter.imax  # mma makes i type of one of these
        setsymval(isym,i)
        doeval(ex)
    end        
end

function do_doloop(expr,iter::SJIter3)
    isym = gensym(string(iter.i))
    ex = replsym(deepcopy(expr),iter.i,isym)
    setsymval(isym,iter.imin)    
    for i in 1:(iter.loopmax)
        doeval(ex)
        setsymval(isym,doeval(mxpr(:Plus,isym,1)))
    end        
end

# TODO model these on code above for SJIter3, which works.
function do_doloop{T<:Real, V<:Real, W<:Real}(expr, iter::SJIter4{T,V,W})
    println("in 4")
    isym = gensym(string(iter.i))
    ex = replsym(deepcopy(expr),iter.i,isym)
    for i in (iter.imin):(iter.di):(iter.imax)
        setsymval(isym,i)
        doeval(ex)
    end        
end

# function do_doloop(expr,iter::SJIter3)
#     isym = gensym(string(iter.i))
#     ex = replsym(deepcopy(expr),iter.i,isym)
#     setsymval(isym,iter.imin)    
#     for i in 1:(iter.loopmax)
#         doeval(ex)
#         setsymval(isym,doeval(mxpr(:Plus,isym,1)))
#     end        
# end

function do_doloop(expr,iter::SJIter4)
    do_doloop_kern4(expr,iter.i,iter.imin,iter.imax, iter.di)
end

# Same here. don't need this kernel
function do_doloop_kern4{T<:Real,V<:Real,W<:Real}(expr,i,imin::T,imax::V,di::W)
    isym = gensym(string(i))
    ex = replsym(deepcopy(expr),i,isym)
    for i in imin:di:imax
        setsymval(isym,i)
        doeval(ex)
    end    
end

do_doloop_kern4(expr,i,imin,imax,di) = error("Not implemented yet.")