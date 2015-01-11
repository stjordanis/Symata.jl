include("./patrule.jl")

using Base.Test

# syntax for constructing a rule
@test  (:a => :b)  == PRule(:a,:b)

# match literal expression; no pattern
@test patrule( :( a ), :( a ), :( b ) ) == :b

# no match
@test patrule( :( a ), :( z ), :( b ) ) == false

# tpatrule acts as identity if there is no match
@test tpatrule( :( a ), :( z ), :( b ) ) == :a

# match pattern and replace
@test patrule( :( a * a ) , :( x_ * x_ ) , :( x_^2 )) == :(a ^ 2)

# same as tpatrule, but second arguement is a PRule
@test replace( :(a*a) , :(x_*x_)  =>  :(x_^2) ) == :(a^2)

# Can use underscore for capture var.
sq_rule = :(_ * _)  =>  :(_^2)

# replace tests the entire expression, not subexpressions
@test replace( :(a*a+1) , sq_rule) == :(a*a+1)

# replaceall tests subexpressions; depth first.
# This differs from Mma, which applies rule top-down and
# stops if there is a success.
@test replaceall(:(a*a+1) , sq_rule) == :(a^2+1)

# applies everywhere
@test replaceall(:(a*a+1 / ((z+y)*(z+y))) , sq_rule) == :(a^2+1/(z + y)^2)

# Note depth first, rather than top level first and then stopping
@test replaceall(:( (a*a) * (a*a) ) , sq_rule) == :((a^2)^2)

## Examples

mulpow_rule = :(x_^n1_ * x_^n2_) => :(x_^(n1_+n2_))

@test replace(:(a^2 * a^3 ), mulpow_rule) == :(a ^ (2 + 3))
@test replace(:(a^1.2 * a^2.3 ), mulpow_rule) == :(a ^ (1.2 + 2.3))

# you can put a condition on the pattern
@test replace(:(a^1.2 * a^2.3 ), :(x_^n1_::Int * x_^n2_::Int) => :(x_^(n1_+n2_)) ) ==
    :(a ^ 1.2 * a ^ 2.3)
@test replace(:(a^5 * a^6 ), :(x_^n1_::Int * x_^n2_::Int) => :(x_^(n1_+n2_)) ) ==
    :(a ^ (5 + 6))        

# This is much faster because the Int is evaluated when the pattern is constructed
@test replace(:(a^3 * a^5 ), :(x_^n1_::$(Int) * x_^n2_::$(Int)) => :(x_^(n1_+n2_))) ==
    :(a ^ (3 + 5))

@test string(cmppat( :( "dog" ) , :( x_::$(String) )))  ==
     "(true,Any[(:(pat(x_,AbstractString)),\"dog\")])"

@test replaceall(:( (a^2 * a^3)*a^4 ), mulpow_rule) == :(a ^ ((2 + 3)+4))

inv_rule = :(1/(1/x_)) => :(x_)

@test replace( :( 1/(1/(a+b)) ), inv_rule) == :(a+b)

plusmul_rule = :( x_ + x_ )  =>  :(2 * x_)
mulpow1_rule = :( x_ * x_ )  =>  :(x_^2)

# Tests are tried one at a time until one matches
@test replaceall( :( a * a ), [plusmul_rule, mulpow1_rule]) == :(a^2)
@test replaceall( :( a + a ), [plusmul_rule, mulpow1_rule]) == :(2a)

@test replace( :( sin(a+b)/cos(a+b) ) , :( sin(_) / cos(_) ) => :( tan(_) ) ) == :(tan(a + b))

# Test anonymous functions as conditions
@test (cmppat1( :( 3 ) , :( x_::((x)->(x>4)) )))[1] == false
@test (cmppat1( :( 3 ) , :( x_::((x)->(x>2)) )))[1] == true
