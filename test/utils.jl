struct MiniApp
	jg::JobGraph
	fromGUI::Channel{Pair{Symbol,Vector}}
	toGUI::Channel{Pair{Symbol,Any}}
	lastSchedulerTime::Ref{UInt64}
end
MiniApp() = MiniApp(JobGraph(), Channel{Pair{Symbol,Vector}}(Inf), Channel{Pair{Symbol,Any}}(Inf), Ref{UInt64}(0))

setvalue(app::MiniApp, value::Array{Any}) = put!(app.fromGUI, :setvalue=>value)

function init(app::MiniApp)
	setvalue(app, Any["samplesimplexmethod", "SA"])
	setvalue(app, Any["loadrowsassamples", "true"])
	setvalue(app, Any["normalizemethod", "Mean=0"])
	setvalue(app, Any["dimreductionmethod", "PMA"])
	setvalue(app, Any["knearestneighbors", "0"])
	setvalue(app, Any["distnearestneighbors", "0"])
	setvalue(app, Any["xaxis", "1"])
	setvalue(app, Any["yaxis", "2"])
	setvalue(app, Any["zaxis", "3"])
	setvalue(app, Any["plotwidth", "1024"])
	setvalue(app, Any["plotheight", "768"])
	setvalue(app, Any["showpoints", "true"])
	setvalue(app, Any["showlines", "true"])
	setvalue(app, Any["showtriangles", "false"])
	setvalue(app, Any["markersize", "4"])
	setvalue(app, Any["linewidth", "1"])
	setvalue(app, Any["triangleopacity", "0.05"])
	setvalue(app, Any["colorby", "Auto"])
	setvalue(app, Any["exportmode", "Variables"])
	setvalue(app, Any["exportsingledim", "1"])
	setvalue(app, Any["exportsinglesort", "Abs"])
	setvalue(app, Any["exportmultipledim", "3"]	)
end

function runall(app::MiniApp)
	while isready(app.fromGUI) || wantstorun(app.jg.scheduler) || isactive(app.jg.scheduler)
		process_step(app.jg, app.fromGUI, app.toGUI, app.lastSchedulerTime) || return false
	end
	true
end

function factorizationcmp(F1,F2)
	@test size(F1.U)==size(F2.U)
	@test size(F1.S)==size(F2.S)
	@test size(F1.V)==size(F2.V)
	@test size(F1.Vt)==size(F2.Vt)
	@test F1.S ≈ F2.S
	sgn = sign.(diag(F1.U'F2.U))
	@test F1.U.*sgn' ≈ F2.U
	@test F1.V.*sgn' ≈ F2.V
	@test F1.Vt.*sgn ≈ F2.Vt
	nothing
end
