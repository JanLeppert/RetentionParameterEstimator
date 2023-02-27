# functions defining the loss-function

"""
    tR_calc(Tchar, θchar, ΔCp, L, d, prog, gas; opt=std_opt)

Calculates the retention time tR for a solute with the K-centric parameters `Tchar` `θchar` and `ΔCp` for a column with length `L`, internal diameter `d`, the (conventional) program `prog`, options `opt` and mobile phase `gas`.
For this calculation only the ODE for the migration of a solute in a GC column is solved, using the function `GasChromatographySimulator.solving_migration`.
"""
function tR_calc(Tchar, θchar, ΔCp, L, d, prog, gas; opt=std_opt)
	# df has no influence on the result (is hidden in Tchar, θchar, ΔCp)
	k(x,t,Tchar_,θchar_,ΔCp_) = exp((ΔCp_/R + Tchar_/θchar_)*(Tchar_/prog.T_itp(x,t)-1) + ΔCp_/R*real(log(Complex(prog.T_itp(x,t)/Tchar_))))
	rM(x,t,L_,d_) = GasChromatographySimulator.mobile_phase_residency(x,t, prog.T_itp, prog.Fpin_itp, prog.pout_itp, L_, d_, gas; ng=opt.ng, vis=opt.vis, control=opt.control)
	
	r(t,p,x) = (1+k(x,t,p[1],p[2],p[3]))*rM(x,t,p[4],p[5])
	
	t₀ = 0.0
	xspan = (0.0, L)
	p = [Tchar, θchar, ΔCp, L, d]
	prob = ODEProblem(r, t₀, xspan, p)
	solution = solve(prob, alg=opt.alg, abstol=opt.abstol, reltol=opt.reltol)
	tR = solution.u[end]
	return tR
end


function tR_calc(Tchar, θchar, ΔCp, φ₀, L, d, df, prog, gas; opt=std_opt)
	# df has no influence on the result (is hidden in Tchar, θchar, ΔCp)
	solution = GasChromatographySimulator.solving_migration(Tchar, θchar, ΔCp, φ₀, L, d, df, prog, opt, gas)
	tR = solution.u[end]
	return tR
end


"""
    loss(tR, Tchar, θchar, ΔCp, L, d, prog, gas; opt=std_opt, metric="squared")

Loss function as sum of squares of the residuals between the measured and calculated retention times.
    
# Arguments
* `tR` ... mxn-array of the measured retention times in seconds.
* `Tchar` ... n-array of characteristic temperatures in K.
* `θchar` ... n-array of characteristic constants in °C.
* `ΔCp` ... n-array of the change of adiabatic heat capacity in J mol^-1 K^-1.
* `L` ... number of the length of the column in m.
* `d` ... number of the diameters of the column in m.
* `prog` ... m-array of structure GasChromatographySimulator.Programs containing the definition of the GC-programs.
* `gas` ... string of name of the mobile phase gas. 

# Output
The output is a tuple of the following quantites:
* `sum((tR.-tRcalc).^2)` ... sum of the squared residuals over m GC-programs and n solutes.
"""
function loss(tR, Tchar, θchar, ΔCp, L, d, prog, gas; opt=std_opt, metric="squared")
	if length(size(tR)) == 1
		ns = 1 # number of solutes
		np = size(tR)[1] # number of programs
	elseif length(size(tR)) == 0
		ns = 1
		np = 1
	else
		ns = size(tR)[2]
		np = size(tR)[1]
	end
	tRcalc = Array{Any}(undef, np, ns)
	for j=1:ns
		for i=1:np
			tRcalc[i,j] = tR_calc(Tchar[j], θchar[j], ΔCp[j], L, d, prog[i], gas; opt=opt)
		end
	end
	if metric == "abs"
		l = sum(abs.(tR.-tRcalc))/(ns*np)
	elseif metric == "squared"
		l = sum((tR.-tRcalc).^2)/(ns*np)
	else
		l = sum((tR.-tRcalc).^2)/(ns*np)
	end
	return l
end

function loss(tR, Tchar, θchar, ΔCp, φ₀, L, d, df, prog, gas; opt=std_opt, metric="squared")
	if length(size(tR)) == 1
		ns = 1 # number of solutes
		np = size(tR)[1] # number of programs
	elseif length(size(tR)) == 0
		ns = 1
		np = 1
	else
		ns = size(tR)[2]
		np = size(tR)[1]
	end
	tRcalc = Array{Any}(undef, np, ns)
	for j=1:ns
		for i=1:np
			tRcalc[i,j] = tR_calc(Tchar[j], θchar[j], ΔCp[j], φ₀, L, d, df, prog[i], gas; opt=opt)
		end
	end
	if metric == "abs"
		l = sum(abs.(tR.-tRcalc))/(ns*np)
	elseif metric == "squared"
		l = sum((tR.-tRcalc).^2)/(ns*np)
	else
		l = sum((tR.-tRcalc).^2)/(ns*np)
	end
	return l
end

function tR_calc_(A, B, C, L, d, β, prog, gas; opt=std_opt)
	k(x,t,A_,B_,C_,β_) = exp(A_ + B_/prog.T_itp(x,t) + C_*log(prog.T_itp(x,t)) - log(β_))
	#rM(x,t,L,d) = GasChromatographySimulator.mobile_phase_residency(x,t, prog.T_itp, prog.Fpin_itp, prog.pout_itp, L, d, gas; ng=opt.ng, vis=opt.vis, control=opt.control)
	rM(x,t,L_,d_) = 64 * sqrt(prog.Fpin_itp(t)^2 - x/L*(prog.Fpin_itp(t)^2-prog.pout_itp(t)^2)) / (prog.Fpin_itp(t)^2-prog.pout_itp(t)^2) * L_/d_^2 * GasChromatographySimulator.viscosity(x, t, prog.T_itp, gas, vis=opt.vis) * prog.T_itp(x, t)
	r(t,p,x) = (1+k(x,t,p[1],p[2],p[3], p[6]))*rM(x,t,p[4],p[5])
	t₀ = 0.0
	xspan = (0.0, L)
	p = [A, B, C, L, d, β]
	prob = ODEProblem(r, t₀, xspan, p)
	solution = solve(prob, alg=opt.alg, abstol=opt.abstol, reltol=opt.reltol)
	tR = solution.u[end]
	return tR
end

function loss_(tR, A, B, C, L, d, β, prog, gas; opt=std_opt, metric="squared")
	# loss function as sum over all programs and solutes
	if length(size(tR)) == 1
		ns = 1 # number of solutes
		np = size(tR)[1] # number of programs
	elseif length(size(tR)) == 0
		ns = 1
		np = 1
	else
		ns = size(tR)[2]
		np = size(tR)[1]
	end
	tRcalc = Array{Any}(undef, np, ns)
	for j=1:ns
		for i=1:np
			tRcalc[i,j] = tR_calc(A[j], B[j], C[j], L, d, β, prog[i], opt, gas)
		end
	end
	if metric == "abs"
		l = sum(abs.(tR.-tRcalc))/(ns*np)
	elseif metric == "squared"
		l = sum((tR.-tRcalc).^2)/(ns*np)
	else
		l = sum((tR.-tRcalc).^2)/(ns*np)
	end
	return l, tRcalc
end	