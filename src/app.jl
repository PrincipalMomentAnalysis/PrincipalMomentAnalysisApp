struct JobGraph
	scheduler::Scheduler
	sampleStatus::Ref{String}
	fileIOLock::ReentrantLock
	paramIDs::Dict{String,JobID}
	loadSampleID::JobID
	normalizeID::JobID
	setupSimplicesID::JobID
	dimreductionID::JobID
	makeplotID::JobID
	exportSingleID::JobID
	exportMultipleID::JobID
end

struct SampleData
	data::Matrix
	sa::DataFrame
	va::DataFrame
end
SampleData() = SampleData(zeros(0,0),DataFrame(),DataFrame(),"")

struct ReducedSampleData
	F::Factorization
	sa::DataFrame
	va::DataFrame
end


guesslastsampleannot(df::DataFrame) =
	something(findlast(col->!(eltype(col)<:Union{Real,Missing}), eachcol(df)), 1) # a reasonable guess for which column to use as the last sample annotation

getdelim(filepath::String) = lowercase(splitext(filepath)[2])==".csv" ? ',' : '\t'

loadcsv(filepath::String; delim, transpose::Bool=false) =
	DataFrame(CSV.File(filepath; delim=delim, transpose=transpose, use_mmap=false, threaded=false)) # threaded=false and perhaps use_mmap=false are needed to avoid crashes

function loadsample(st, input::Dict{String,Any})::DataFrame
	@assert length(input)==2
	filepath = input["filepath"]::String
	rowsAsSamples   = parse(Bool,input["rowsassamples"])
	filepath == :__INVALID__ && return Nothing
	filepath::String
	isempty(filepath) && return Nothing
	@assert isfile(filepath) "Sample file not found: \"$filepath\""
	df = loadcsv(filepath; delim=getdelim(filepath), transpose=!rowsAsSamples)
	@assert size(df,2)>1 "Invalid data set. Must contain at least one sample annotation and one variable."
	@assert guesslastsampleannot(df)<size(df,2) "Invalid data set. Numerical data (variables) must come after sample annotations."
	df
end


# callback function
function showsampleannotnames(df::DataFrame, toGUI)
	indLastSampleAnnot = guesslastsampleannot(df)
	put!(toGUI, :displaysampleannotnames=>(names(df)[1:min(max(indLastSampleAnnot+10,40),end)], indLastSampleAnnot))
end


function normalizesample(st, input::Dict{String,Any})
	@assert length(input)==3
	df = input["dataframe"]
	method = input["method"]
	lastSampleAnnot = input["lastsampleannot"]
	@assert method in ("None", "Mean=0", "Mean=0,Std=1")

	nbrSampleAnnots = findfirst(x->string(x)==lastSampleAnnot, names(df))
	@assert nbrSampleAnnots != nothing "Couldn't find sample annotation: \"$lastSampleAnnot\""

	sa = df[:, 1:nbrSampleAnnots]
	va = DataFrame(VariableID=names(df)[nbrSampleAnnots+1:end])
	originalData = convert(Matrix, df[!,nbrSampleAnnots+1:end])'
	@assert eltype(originalData) <: Union{Number,Missing}

	data = zeros(size(originalData))
	if any(ismissing,originalData)
		# Replace missing values with mean over samples with nonmissing data
		@info "Reconstructing missing values (taking the mean over all nonmissing samples)"
		for i=1:size(data,1)
			m = ismissing.(originalData[i,:])
			data[i,.!m] .= originalData[i,.!m]
			data[i,m] .= mean(originalData[i,.!m])
		end
	else
		data .= originalData # just copy
	end


	X = data
	if method == "Mean=0,Std=1"
		X = normalizemeanstd!(X)
	elseif method == "Mean=0"
		X = normalizemean!(X)
	end
	SampleData(X,sa,va)
end


function setupsimplices(st, input::Dict{String,Any})
	@assert length(input)==6
	sampleData  = input["sampledata"]
	method      = Symbol(input["method"])
	sampleAnnot = Symbol(input["sampleannot"])
	timeAnnot   = Symbol(input["timeannot"])
	kNN         = parse(Int,input["knearestneighbors"])
	distNN      = parse(Float64, input["distnearestneighbors"])
	@assert method in (:SA,:Time,:NN,:NNSA)

	G = nothing
	if method == :SA
		G = groupsimplices(sampleData.sa[!,sampleAnnot])
	elseif method == :Time
		eltype(sampleData.sa[!,timeAnnot])<:Number || @warn "Expected time annotation to contain numbers, got $(eltype(sampleData.sa[!,timeAnnot])). Fallback to default sorting."
		G = timeseriessimplices(sampleData.sa[!,timeAnnot], groupby=sampleData.sa[!,sampleAnnot])
	elseif method == :NN
		G = neighborsimplices(sampleData.data; k=kNN, r=distNN, dim=50)
	elseif method == :NNSA
		G = neighborsimplices(sampleData.data; k=kNN, r=distNN, dim=50, groupby=sampleData.sa[!,sampleAnnot])
	end
	G
end


function dimreduction(st, input::Dict{String,Any})
	@assert length(input)==3
	sampleData      = input["sampledata"]
	sampleSimplices = input["samplesimplices"]
	method          = Symbol(input["method"])

	X = sampleData.data::Matrix{Float64}

	# dim = 3
	dim = min(10, size(X)...)

	if method==:PMA
		F = pma(X, sampleSimplices, nsv=dim)
	elseif method==:PCA
		F = svdbyeigen(X,nsv=dim)
	end
	ReducedSampleData(F, sampleData.sa, sampleData.va)
end

function makeplot(st, input::Dict{String,Any})
	@assert length(input)==17
	reduced            = input["reduced"]::ReducedSampleData
	dimReductionMethod = Symbol(input["dimreductionmethod"])
	sampleAnnot        = Symbol(input["sampleannot"])
	sampleSimplices    = input["samplesimplices"]
	xaxis              = parse(Int,input["xaxis"])
	yaxis              = parse(Int,input["yaxis"])
	zaxis              = parse(Int,input["zaxis"])
	plotWidth          = parse(Int,input["plotwidth"])
	plotHeight         = parse(Int,input["plotheight"])
	showPoints         = parse(Bool,input["showpoints"])
	showLines          = parse(Bool,input["showlines"])
	showTriangles      = parse(Bool,input["showtriangles"])
	markerSize         = parse(Float64,input["markersize"])
	lineWidth          = parse(Float64,input["linewidth"])
	triangleOpacity    = parse(Float64,input["triangleopacity"])
	colorByMethod      = Symbol(input["colorby"])
	colorAnnot         = Symbol(input["colorannot"])
	# shapeByMethod      = Symbol(input["shapeby"])
	# shapeAnnot         = Symbol(input["shapeannot"])

	title = dimReductionMethod

	colorByMethod == :Auto && (colorAnnot=sampleAnnot)
	colorBy = colorByMethod == :None ? repeat([""],size(reduced.sa,1)) : reduced.sa[!,colorAnnot]
	colorDict = (eltype(colorBy) <: Real) ? nothing : colordict(colorBy)

	shapeBy, shapeDict = nothing, nothing
	# if shapeByMethod == :Custom
	# 	shapeBy = reduced.sa[!,shapeAnnot]
	# 	shapeDict = shapedict(shapeBy)
	# end

	# TODO: handle missing values in sample annotations?

	dims = [xaxis, yaxis, zaxis]
	plotArgs = plotsimplices(reduced.F.V[:,dims],sampleSimplices,colorBy,colorDict, title=title,
	                         drawPoints=showPoints, drawLines=showLines, drawTriangles=showTriangles,
	                         opacity=triangleOpacity, markerSize=markerSize, lineWidth=lineWidth,
	                         shapeBy=shapeBy, shapeDict=shapeDict,
	                         width=plotWidth, height=plotHeight,
	                         xLabel=string("PMA",xaxis), yLabel=string("PMA",yaxis), zLabel=string("PMA",zaxis))
end

showplot(plotArgs, toGUI::Channel) = put!(toGUI, :displayplot=>plotArgs)


function exportsingle(st, input::Dict{String,Any})
	@assert length(input)==5
	reduced  = input["reduced"]::ReducedSampleData
	mode     = Symbol(input["mode"])
	filepath = input["filepath"]
	sortMode = Symbol(input["sort"])
	dim      = parse(Int,input["dim"])
	@assert mode in (:Variables, :Samples)
	@assert sortMode in (:Abs, :Descending, :Ascending, :Original)

	colName = Symbol("PMA",dim)

	if mode == :Variables
		df = copy(reduced.va)
		df[!,colName] = reduced.F.U[:,dim]
	else
		df = copy(reduced.sa[!,1:1])
		df[!,colName] = reduced.F.V[:,dim]
	end


	if sortMode==:Abs
		sort!(df, colName, by=abs, rev=true)
	elseif sortMode==:Descending
		sort!(df, colName, rev=true)
	elseif sortMode==:Ascending
		sort!(df, colName)
	end

	CSV.write(filepath, df, delim=getdelim(filepath))
end

function exportmultiple(st, input::Dict{String,Any})
	@assert length(input)==4
	reduced  = input["reduced"]::ReducedSampleData
	mode     = Symbol(input["mode"])
	filepath = input["filepath"]
	dim      = parse(Int,input["dim"])
	@assert mode in (:Variables, :Samples)

	if mode == :Variables
		df = copy(reduced.va)
		PMAs = reduced.F.U
	else
		df = copy(reduced.sa[!,1:1])
		PMAs = reduced.F.V
	end

	for d in 1:dim
		df[!,Symbol("PMA",d)] = PMAs[:,d]
	end

	CSV.write(filepath, df, delim=getdelim(filepath))
end



function samplestatus(jg::JobGraph)
	status = jobstatus(jg.scheduler, jg.loadSampleID)
	status==:done && return "Sample loaded."
	status in (:waiting,:running) && return "Loading sample."
	"Please load sample."
end

function setsamplestatus(jg::JobGraph, toGUI::Channel)
	sampleStatus = samplestatus(jg)
	sampleStatus!=jg.sampleStatus[] && put!(toGUI, :samplestatus=>sampleStatus)
	jg.sampleStatus[] = sampleStatus
end


function JobGraph()
	scheduler = Scheduler()
	# scheduler = Scheduler(threaded=false) # For DEBUG
	sampleIDs = Dict{String,Tuple{JobID,JobID}}()
	annotIDs  = Dict{String,Tuple{JobID,JobID}}()

	# Data Nodes (i.e. parameters chosen in the GUI)
	paramIDs = Dict{String,JobID}()

	loadSampleID = createjob!(loadsample, scheduler, "loadsample")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"samplefilepath")=>loadSampleID, "filepath")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"loadrowsassamples")=>loadSampleID, "rowsassamples")

	normalizeID = createjob!(normalizesample, scheduler, "normalizesample")
	add_dependency!(scheduler, loadSampleID=>normalizeID, "dataframe")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"lastsampleannot")=>normalizeID, "lastsampleannot")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"normalizemethod")=>normalizeID, "method")

	setupSimplicesID = createjob!(setupsimplices, scheduler, "setupsimplices")
	add_dependency!(scheduler, normalizeID=>setupSimplicesID, "sampledata")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"samplesimplexmethod")=>setupSimplicesID, "method")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"sampleannot")=>setupSimplicesID, "sampleannot")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"timeannot")=>setupSimplicesID, "timeannot")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"knearestneighbors")=>setupSimplicesID, "knearestneighbors")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"distnearestneighbors")=>setupSimplicesID, "distnearestneighbors")

	dimreductionID = createjob!(dimreduction, scheduler, "dimreduction")
	add_dependency!(scheduler, normalizeID=>dimreductionID, "sampledata")
	add_dependency!(scheduler, setupSimplicesID=>dimreductionID, "samplesimplices")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"dimreductionmethod")=>dimreductionID, "method")

	makeplotID = createjob!(makeplot, scheduler, "makeplot")
	add_dependency!(scheduler, dimreductionID=>makeplotID, "reduced")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"dimreductionmethod")=>makeplotID, "dimreductionmethod")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"sampleannot")=>makeplotID, "sampleannot")
	add_dependency!(scheduler, setupSimplicesID=>makeplotID, "samplesimplices")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"xaxis")=>makeplotID, "xaxis")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"yaxis")=>makeplotID, "yaxis")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"zaxis")=>makeplotID, "zaxis")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"plotwidth")=>makeplotID, "plotwidth")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"plotheight")=>makeplotID, "plotheight")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"showpoints")=>makeplotID, "showpoints")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"showlines")=>makeplotID, "showlines")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"showtriangles")=>makeplotID, "showtriangles")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"markersize")=>makeplotID, "markersize")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"linewidth")=>makeplotID, "linewidth")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"triangleopacity")=>makeplotID, "triangleopacity")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"colorby")=>makeplotID, "colorby")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"colorannot")=>makeplotID, "colorannot")
	# add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"shapeby")=>makeplotID, "shapeby")
	# add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"shapeannot")=>makeplotID, "shapeannot")


	exportSingleID = createjob!(exportsingle, scheduler, "exportsingle")
	add_dependency!(scheduler, dimreductionID=>exportSingleID, "reduced")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"exportmode")=>exportSingleID, "mode")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"exportsinglepath")=>exportSingleID, "filepath")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"exportsingledim")=>exportSingleID, "dim")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"exportsinglesort")=>exportSingleID, "sort")

	exportMultipleID = createjob!(exportmultiple, scheduler, "exportmultiple")
	add_dependency!(scheduler, dimreductionID=>exportMultipleID, "reduced")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"exportmode")=>exportMultipleID, "mode")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"exportmultiplepath")=>exportMultipleID, "filepath")
	add_dependency!(scheduler, getparamjobid(scheduler,paramIDs,"exportmultipledim")=>exportMultipleID, "dim")

	JobGraph(scheduler,
	         Ref(""),
	         ReentrantLock(),
	         paramIDs,
	         loadSampleID,
	         normalizeID,
	         setupSimplicesID,
	         dimreductionID,
	         makeplotID,
	         exportSingleID,
	         exportMultipleID)
end

getparamjobid(s::Scheduler, paramIDs::Dict{String,JobID}, name::String, create::Bool=true) = create ? get!(paramIDs,name,createjob!(s, :__INVALID__, name)) : paramIDs[name]
getparamjobid(jg::JobGraph, name::String, args...) = getparamjobid(jg.scheduler, jg.paramIDs,name,args...)
setparam(jg::JobGraph, name::String, value) = setresult!(jg.scheduler, jg.paramIDs[name], value)




function process_thread(jg::JobGraph, fromGUI::Channel, toGUI::Channel)
	try
		scheduler = jg.scheduler
		lastSchedulerTime = UInt64(0)

		while true
			# @info "[Processing] tick"
			timeNow = time_ns()
			if isready(fromGUI)
				try
					msg = take!(fromGUI)
					msgName = msg.first
					msgArgs = msg.second
					@info "[Processing] Got message: $msgName $msgArgs"

					if msgName == :exit
						break
					elseif msgName == :cancel
						@info "[Processing] Cancelling all future events."
						cancelall!(scheduler)
					elseif msgName == :setvalue
						varName = msgArgs[1]
						value = msgArgs[2]
						if haskey(jg.paramIDs, varName)
							setresult!(scheduler, jg.paramIDs[varName], value)
						else
							@warn "Unknown variable name: $varName"
						end
					elseif msgName == :loadsample
						schedule!(x->showsampleannotnames(x,toGUI), scheduler, jg.loadSampleID)
					elseif msgName == :showplot
						schedule!(x->showplot(x,toGUI), scheduler, jg.makeplotID)
					elseif msgName == :exportsingle
						schedule!(scheduler, jg.exportSingleID)
					elseif msgName == :exportmultiple
						schedule!(scheduler, jg.exportMultipleID)
					else
						@warn "Unknown message type: $(msgName)"
					end
				catch e
					@warn "[Processing] Error processing GUI message."
					showerror(stdout, e, catch_backtrace())
				end
				setsamplestatus(jg, toGUI)
			elseif wantstorun(scheduler) || (isactive(scheduler) && (timeNow-lastSchedulerTime)/1e9 > 5.0)
				lastSchedulerTime = timeNow
				try
					step!(scheduler)
					status = statusstring(scheduler)
					@info "Job status: $status"
				catch e
					@warn "[Processing] Error processing event."
					showerror(stdout, e, catch_backtrace())
				end
				setsamplestatus(jg, toGUI)
			else
				yield()
			end
		end

	catch e
		@warn "[Processing] Fatal error."
		showerror(stdout, e, catch_backtrace())
	end
	@info "[Processing] Exiting thread."
	put!(toGUI, :exited=>nothing)
end


"""
	pmaapp()

Start the Principal Moment Analysis App.
"""
function pmaapp(; return_job_graph=false)
	# This is the GUI thread

	jg = JobGraph()

	@info "[PMAGUI] Using $(Threads.nthreads()) of $(Sys.CPU_THREADS) available threads."
	Threads.nthreads() == 1 && @warn "[PMAGUI] Threading not enabled, please set the environment variable JULIA_NUM_THREADS to the desired number of threads."

	# init
	fromGUI = Channel{Pair{Symbol,Vector}}(Inf)
	toGUI   = Channel{Pair{Symbol,Any}}(Inf)

	# start processing thread
	processingThreadRunning = true
	Threads.@spawn process_thread(jg, fromGUI, toGUI)

	# setup gui
	w = Window(Dict(:width=>512,:height=>768))

	# event listeners
	handle(w, "msg") do args
		msgName = Symbol(args[1])
		msgArgs = args[2:end]
		@info "[GUI] sending message: $msgName $(join(msgArgs,", "))"
		processingThreadRunning && put!(fromGUI, msgName=>msgArgs)
	end

	doc = read(joinpath(@__DIR__,"content.html"),String)
	body!(w,doc,async=false)
	js(w, js"init()")

	while isopen(w.content.sock) # is there a better way to check if the window is still open?
		# @info "[GUI] tick"

		if isready(toGUI)
			msg = take!(toGUI)
			msgName = msg.first
			msgArgs = msg.second
			@info "[GUI] got message: $msgName"

			if msgName == :samplestatus
				js(w, js"""setSampleStatus($msgArgs)""")
			elseif msgName == :displayplot
				display(plot(msgArgs...))
			elseif msgName == :displaysampleannotnames
				js(w, js"""setSampleAnnotNames($(msgArgs[1]), $(msgArgs[2]-1))""")
			elseif msgName == :exited
				processingThreadRunning = false
			end
		end
		yield() # Allow GUI to run
	end

	@info "[GUI] Waiting for scheduler thread to finish."
	processingThreadRunning && put!(fromGUI, :exit=>[])
	# wait until all threads have exited
	while processingThreadRunning
		msg = take!(toGUI)
		msgName = msg.first
		msgArgs = msg.second
		@info "[GUI] got message: $msgName"
		msgName == :exited && (processingThreadRunning = false)
		sleep(0.05)
	end
	@info "[GUI] Scheduler thread finished."

	return_job_graph ? jg : nothing
end

