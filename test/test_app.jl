struct MiniApp
	jg::JobGraph
	fromGUI::Channel{Pair{Symbol,Vector}}
	toGUI::Channel{Pair{Symbol,Any}}
end
MiniApp() = MiniApp(JobGraph(), Channel{Pair{Symbol,Vector}}(Inf), Channel{Pair{Symbol,Any}}(Inf))

function init(app::MiniApp)
	put!(app.fromGUI, :setvalue=>Any["samplesimplexmethod", "SA"])
	put!(app.fromGUI, :setvalue=>Any["loadrowsassamples", "true"])
	put!(app.fromGUI, :setvalue=>Any["normalizemethod", "Mean=0"])
	put!(app.fromGUI, :setvalue=>Any["dimreductionmethod", "PMA"])
	put!(app.fromGUI, :setvalue=>Any["knearestneighbors", "0"])
	put!(app.fromGUI, :setvalue=>Any["distnearestneighbors", "0"])
	put!(app.fromGUI, :setvalue=>Any["xaxis", "1"])
	put!(app.fromGUI, :setvalue=>Any["yaxis", "2"])
	put!(app.fromGUI, :setvalue=>Any["zaxis", "3"])
	put!(app.fromGUI, :setvalue=>Any["plotwidth", "1024"])
	put!(app.fromGUI, :setvalue=>Any["plotheight", "768"])
	put!(app.fromGUI, :setvalue=>Any["showpoints", "true"])
	put!(app.fromGUI, :setvalue=>Any["showlines", "true"])
	put!(app.fromGUI, :setvalue=>Any["showtriangles", "false"])
	put!(app.fromGUI, :setvalue=>Any["markersize", "4"])
	put!(app.fromGUI, :setvalue=>Any["linewidth", "1"])
	put!(app.fromGUI, :setvalue=>Any["triangleopacity", "0.05"])
	put!(app.fromGUI, :setvalue=>Any["colorby", "Auto"])
	put!(app.fromGUI, :setvalue=>Any["exportmode", "Variables"])
	put!(app.fromGUI, :setvalue=>Any["exportsingledim", "1"])
	put!(app.fromGUI, :setvalue=>Any["exportsinglesort", "Abs"])
	put!(app.fromGUI, :setvalue=>Any["exportmultipledim", "3"]	)
end

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

@testset "asyncexit" begin
	app = MiniApp()
	put!(app.fromGUI, :exit=>[])
	@async process_thread(app.jg, app.fromGUI, app.toGUI)
	didExit = false
	for i=1:100
		if isready(app.toGUI)
			msg = take!(app.toGUI)
			msg.first == :exited && (didExit=true; break)
		end
		sleep(0.05) # max runtime ~5s
	end
	@test didExit
end


end