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
	@test size(dfSample)==(20,3+40)

	# Dimension Reduction
	setvalue(app, Any["samplesimplexmethod", "SA"])
	setvalue(app, Any["sampleannot", "Group"])
	put!(app.fromGUI, :dimreduction=>[])
	@test runall(app)
	reduced = app.jg.scheduler.jobs[app.jg.dimreductionID].result
	@test reduced.sa == dfSample[!,1:3]
	@test reduced.va[!,1] == varIds
	@test size(reduced.F.U)==(40,10)
	@test size(reduced.F.S)==(10,)
	@test size(reduced.F.V)==(20,10)

	# Exit
	put!(app.fromGUI, :exit=>[])
	@test !runall(app)
end


end