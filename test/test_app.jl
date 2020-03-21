@testset "app" begin

@testset "exit" begin
	app = MiniApp()
	put!(app.fromGUI, :exit=>[])
	process_thread(app.jg, app.fromGUI, app.toGUI)
	didExit = false
	while true
		@test isready(app.toGUI)
		msg = take!(app.toGUI)
		msg.first == :exited && (didExit=true; break)
	end
	@test didExit
end

@testset "exit2" begin
	app = MiniApp()
	init(app)
	lastSchedulerTime = Ref{UInt64}(0)
	put!(app.fromGUI, :exit=>[])
	@test !runall(app)
end

@testset "data.tsv" begin
	filepath = joinpath(@__DIR__, "data/data.tsv")

	varIds = [Symbol("V$i") for i=1:40]
	sampleIds = [string('S',lpad(i,2,'0')) for i=1:20]
	groupAnnot = repeat(["A","B"],inner=10)
	timeAnnot = vcat(0.01:0.01:0.1, 0.01:0.01:0.1)

	app = MiniApp()
	init(app)

	# Open file
	setvalue(app, Any["samplefilepath", filepath])
	setvalue(app, Any["lastsampleannot", "Time"])
	put!(app.fromGUI, :loadsample=>[])
	@test runall(app)
	dfSample = app.jg.scheduler.jobs[app.jg.loadSampleID].result
	@test names(dfSample) == vcat([:SampleId, :Group, :Time], varIds)
	@test dfSample.SampleId == sampleIds
	@test dfSample.Group == groupAnnot
	@test dfSample.Time == timeAnnot
	@test size(dfSample)==(20,3+40)

	X = Matrix(convert(Matrix{Float64}, dfSample[:,4:end])')
	normalizemean!(X)

	# PMA (groups)
	setvalue(app, Any["samplesimplexmethod", "SA"])
	setvalue(app, Any["sampleannot", "Group"])
	put!(app.fromGUI, :dimreduction=>[])
	@test runall(app)
	reduced = app.jg.scheduler.jobs[app.jg.dimreductionID].result
	@test reduced.sa == dfSample[!,1:3]
	@test reduced.va[!,1] == varIds
	factorizationcmp(pma(X, groupsimplices(groupAnnot); nsv=10), reduced.F)

	# PMA (time series)
	setvalue(app, Any["samplesimplexmethod", "Time"])
	setvalue(app, Any["sampleannot", "Group"])
	setvalue(app, Any["timeannot", "Time"])
	put!(app.fromGUI, :dimreduction=>[])
	@test runall(app)
	reduced = app.jg.scheduler.jobs[app.jg.dimreductionID].result
	@test reduced.sa == dfSample[!,1:3]
	@test reduced.va[!,1] == varIds
	#factorizationcmp(pma(X, timeseriessimplices(timeAnnot, groupby=groupAnnot); nsv=10), reduced.F)
	G = timeseriessimplices(timeAnnot, groupby=groupAnnot)
	factorizationcmp(pma(X, G; nsv=10), reduced.F)

	# PMA (NN)
	setvalue(app, Any["samplesimplexmethod", "NN"])
	setvalue(app, Any["knearestneighbors", "2"])
	setvalue(app, Any["distnearestneighbors", "0.5"])
	put!(app.fromGUI, :dimreduction=>[])
	@test runall(app)
	reduced = app.jg.scheduler.jobs[app.jg.dimreductionID].result
	@test reduced.sa == dfSample[!,1:3]
	@test reduced.va[!,1] == varIds
	factorizationcmp(pma(X, neighborsimplices(X,k=2,r=0.5,dim=50), nsv=10), reduced.F)

	# PMA (NN withing groups)
	setvalue(app, Any["samplesimplexmethod", "NNSA"])
	setvalue(app, Any["sampleannot", "Group"])
	setvalue(app, Any["knearestneighbors", "2"])
	setvalue(app, Any["distnearestneighbors", "0.5"])
	put!(app.fromGUI, :dimreduction=>[])
	@test runall(app)
	reduced = app.jg.scheduler.jobs[app.jg.dimreductionID].result
	@test reduced.sa == dfSample[!,1:3]
	@test reduced.va[!,1] == varIds
	factorizationcmp(pma(X, neighborsimplices(X,k=2,r=0.5,dim=50,groupby=groupAnnot), nsv=10), reduced.F)


	# Exit
	put!(app.fromGUI, :exit=>[])
	@test !runall(app)
end


end