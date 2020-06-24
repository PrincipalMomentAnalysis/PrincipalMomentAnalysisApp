function plotsimplices(V, sg, colorBy, colorDict;
	                   drawPoints=true, drawLines=true, drawTriangles=true,
	                   title="",
	                   opacity=0.3, markerSize=5, lineWidth=2,
	                   shapeBy=nothing, shapeDict=nothing,
	                   width=1536, height=768,
	                   xLabel="x", yLabel="y", zLabel="z",
	                   legendTitle="",
	                   cameraAttr=attr())
	traces = GenericTrace[]

	# plot each group in different colors
	if drawPoints
		# TODO: merge the two cases below?

		if colorDict != nothing
			for cb in unique(colorBy)
				ind = findall(colorBy.==cb )
				col = colorDict[cb]

				extras = []
				shapeBy!=nothing && shapeDict!=nothing && push!(extras, (marker_symbol=[shapeDict[k] for k in shapeBy[ind]],))
				isempty(extras) || (extras = pairs(extras...))

				points = scatter3d(;x=V[ind,1],y=V[ind,2],z=V[ind,3], mode="markers", marker_color=col, marker_size=markerSize, marker_line_width=0, name=string(cb), extras...)
				push!(traces, points)
			end
		else
			extras = []
			shapeBy!=nothing && shapeDict!=nothing && push!(extras, (marker_symbol=[shapeDict[k] for k in shapeBy],))
			isempty(extras) || (extras = pairs(extras...))

			points = scatter3d(;x=V[:,1],y=V[:,2],z=V[:,3], mode="markers", marker=attr(color=colorBy, colorscale="Viridis", showscale=true, size=markerSize, line_width=0, colorbar=attr(title=legendTitle)), name="", extras...)
			push!(traces, points)
		end
	end

	if drawLines
		LINE_LIMIT = 300_000

		x = Union{Nothing,Float64}[]
		y = Union{Nothing,Float64}[]
		z = Union{Nothing,Float64}[]
		colorsRGB    = RGB{Float64}[]
		colorsScalar = Float64[]
		GK = sg.G*sg.G'

		nbrLines = 0
		for (r,c,_) in zip(findnz(GK)...)
			r>c || continue # just use lower triangular part
			push!(x, V[r,1], V[c,1], nothing)
			push!(y, V[r,2], V[c,2], nothing)
			push!(z, V[r,3], V[c,3], nothing)
			if colorDict==nothing
				push!(colorsScalar, colorBy[r], colorBy[c], colorBy[c])
			else
				push!(colorsRGB, colorDict[colorBy[r]], colorDict[colorBy[c]], RGB(0.,0.,0.))
			end

			nbrLines += 1
			nbrLines>LINE_LIMIT && break
		end

		if nbrLines > LINE_LIMIT
			@warn "More than $LINE_LIMIT lines to plot, disabling line plotting for performance reasons."
		else
			if colorDict==nothing
				push!(traces, scatter3d(;x=x,y=y,z=z, mode="lines", line=attr(color=colorsScalar, colorscale="Viridis", width=lineWidth), showlegend=false))
			else
				push!(traces, scatter3d(;x=x,y=y,z=z, mode="lines", line=attr(color=colorsRGB, width=lineWidth), showlegend=false))
			end
		end
	end

	if drawTriangles
		TRIANGLE_LIMIT = 2_000_000

		triangleInds = Int[]
		for c=1:size(sg.G,2)
			ind = findall(sg.G[:,c])
			isempty(ind) && continue

			length(ind)<3 && continue # no triangles

			# slow and ugly solution
			for tri in subsets(ind,3)
				append!(triangleInds, sort(tri))
			end
		end
		triangleInds = reshape(triangleInds,3,:)
		triangleInds = unique(triangleInds,dims=2) # remove duplicates
		triangleInds .-= 1 # PlotlyJS wants zero-based indices

		if size(triangleInds,2)>TRIANGLE_LIMIT
			@warn "More than $TRIANGLE_LIMIT triangles to plot, disabling triangle plotting for performance reasons."
		else
			if colorDict==nothing
				push!(traces, mesh3d(; x=V[:,1],y=V[:,2],z=V[:,3],i=triangleInds[1,:],j=triangleInds[2,:],k=triangleInds[3,:], intensity=colorBy, colorscale="Viridis", opacity=opacity, showlegend=false))
			else
				vertexColor = getindex.((colorDict,), colorBy)
				push!(traces, mesh3d(; x=V[:,1],y=V[:,2],z=V[:,3],i=triangleInds[1,:],j=triangleInds[2,:],k=triangleInds[3,:], vertexcolor=vertexColor, opacity=opacity, showlegend=false))
			end
		end
	end


	layout = Layout(autosize=false, width=width, height=height, margin=attr(l=0, r=0, b=0, t=65), title=title,
	                scene=attr(xaxis=attr(title=xLabel), yaxis=attr(title=yLabel), zaxis=attr(title=zLabel), camera=cameraAttr),
	                legend=attr(title_text=legendTitle, itemsizing="constant"))
	# layout = Layout(margin=attr(l=0, r=0, b=0, t=65), title=title)
	#plot(traces, layout)
	traces, layout # return plot args rather than plot because of threading issues.
end

_distinguishable_colors(n) = distinguishable_colors(n+1,colorant"white")[2:end]

function colordict(x::AbstractArray)
	k = unique(x)
	Dict(s=>c for (s,c) in zip(k,_distinguishable_colors(length(k))))
end

const SHAPES = ["circle","square","diamond","cross","x","triangle-up","triangle-down","triangle-left","triangle-right","triangle-ne","triangle-se","triangle-sw","triangle-nw","pentagon","hexagon","hexagon2","octagon","star","hexagram","star-triangle-up","star-triangle-down","star-square","star-diamond","diamond-tall","diamond-wide","hourglass","bowtie","circle-cross","circle-x","square-cross","square-x","diamond-cross","diamond-x","cross-thin","x-thin","asterisk","hash","y-up","y-down","y-left","y-right","line-ew","line-ns","line-ne","line-nw","circle-open","square-open","diamond-open","cross-open","x-open","triangle-up-open","triangle-down-open","triangle-left-open","triangle-right-open","triangle-ne-open","triangle-se-open","triangle-sw-open","triangle-nw-open","pentagon-open","hexagon-open","hexagon2-open","octagon-open","star-open","hexagram-open","star-triangle-up-open","star-triangle-down-open","star-square-open","star-diamond-open","diamond-tall-open","diamond-wide-open","hourglass-open","bowtie-open","circle-cross-open","circle-x-open","square-cross-open","square-x-open","diamond-cross-open","diamond-x-open","cross-thin-open","x-thin-open","asterisk-open","hash-open","y-up-open","y-down-open","y-left-open","y-right-open","line-ew-open","line-ns-open","line-ne-open","line-nw-open","","circle-dot","square-dot","diamond-dot","cross-dot","x-dot","triangle-up-dot","triangle-down-dot","triangle-left-dot","triangle-right-dot","triangle-ne-dot","triangle-se-dot","triangle-sw-dot","triangle-nw-dot","pentagon-dot","hexagon-dot","hexagon2-dot","octagon-dot","star-dot","hexagram-dot","star-triangle-up-dot","star-triangle-down-dot","star-square-dot","star-diamond-dot","diamond-tall-dot","diamond-wide-dot","hash-dot","circle-open-dot","square-open-dot","diamond-open-dot","cross-open-dot","x-open-dot","triangle-up-open-dot","triangle-down-open-dot","triangle-left-open-dot","triangle-right-open-dot","triangle-ne-open-dot","triangle-se-open-dot","triangle-sw-open-dot","triangle-nw-open-dot","pentagon-open-dot","hexagon-open-dot","hexagon2-open-dot","octagon-open-dot","star-open-dot","hexagram-open-dot","star-triangle-up-open-dot","star-triangle-down-open-dot","star-square-open-dot","star-diamond-open-dot","diamond-tall-open-dot","diamond-wide-open-dot","hash-open-dot"]
shapedict(x::AbstractArray) = Dict(v=>SHAPES[mod(i-1,length(SHAPES))+1] for (i,v) in enumerate(unique(x)))
