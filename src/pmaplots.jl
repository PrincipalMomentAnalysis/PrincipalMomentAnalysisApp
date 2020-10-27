function _scatter(V; kwargs...)
	size(V,2)==2 && return scatter(;x=V[:,1], y=V[:,2], kwargs...)
	scatter3d(;x=V[:,1], y=V[:,2], z=V[:,3], kwargs...)
end

function plotsimplices(V, sg, colorBy, colorDict;
	                   drawPoints=true, drawLines=true, drawTriangles=true,
	                   title="",
	                   opacity=0.3, markerSize=5, lineWidth=2,
	                   shapeBy=nothing, shapeDict=nothing,
	                   xLabel="x", yLabel="y", zLabel="z",
	                   legendTitle="",
	                   cameraAttr=attr())
	@assert size(V,2) in 2:3

	traces = GenericTrace[]

	# colorscale setup
	colorScale = nothing
	tOffs, tScale = 0.0, 1.0
	if colorDict==nothing
		# this is the "RdBu" colorscale used by PlotlyJS
		colorScale = ColorScale([0, 0.35, 0.5, 0.6, 0.7, 1], [RGB(5/255,10/255,172/255), RGB(106/255,137/255,247/255), RGB(190/255,190/255,190/255), RGB(220/255,170/255,132/255), RGB(230/255,145/255,90/255), RGB(178/255,10/255,28/255)])

		if !isempty(skipmissing(colorBy))
			m,M = Float64.(extrema(skipmissing(colorBy)))
			tOffs,tScale = M>m ? (m, 1.0./(M-m)) : (m-0.5, 1.0) # if there is only one unique value, map it to the middle of the colorscale
		end
	end

	if drawTriangles && size(V,2)>2 # Triangles not supported in 2d plot for now
		TRIANGLE_LIMIT = 2_000_000

		triangleInds = Int[]
		for c=1:size(sg.G,2)
			ind = findall(sg.G[:,c])
			isempty(ind) && continue

			length(ind)<3 && continue # no triangles

			# slow and ugly solution
			for tri in IterTools.subsets(ind,3)
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
				vertexColor = [ ismissing(t) ? RGB(0.,0.,0.) : lookup(colorScale, (t-tOffs)*tScale) for t in colorBy ]
			else
				vertexColor = getindex.((colorDict,), colorBy)
			end
			push!(traces, mesh3d(; x=V[:,1],y=V[:,2],z=V[:,3],i=triangleInds[1,:],j=triangleInds[2,:],k=triangleInds[3,:], vertexcolor=vertexColor, opacity=opacity, lighting=attr(ambient=1.0,diffuse=0.0,specular=0.0,fresnel=0.0), showlegend=false))

		end
	end

	if drawLines
		LINE_LIMIT = 300_000

		GK = sg.G*sg.G'
		nbrLines = div(nnz(GK) - sum(i->GK[i,i]>0, 1:size(GK,1)), 2) # number of elements above the diagonal

		if nbrLines > LINE_LIMIT
			@warn "More than $LINE_LIMIT lines to plot, disabling line plotting for performance reasons."
		else
			# every third point is "nothing" to make lines disconnected
			VL = repeat(Union{Float64,Nothing}[nothing], nbrLines*3, size(V,2))
			colorsRGB = repeat([RGB(0.,0.,0.)], nbrLines*3)

			lineInd = 1
			rows = rowvals(GK)
			for c = 1:size(GK,2)
				for k in nzrange(GK, c)
					r = rows[k]
					r>=c && break # just use upper triangular part
					VL[lineInd,   :] .= V[r,:]
					VL[lineInd+1, :] .= V[c,:]

					if colorDict==nothing
						t1,t2 = colorBy[r],colorBy[c]
						col1 = ismissing(t1) ? RGB(0.,0.,0.) : lookup(colorScale, (t1-tOffs)*tScale)
						col2 = ismissing(t2) ? RGB(0.,0.,0.) : lookup(colorScale, (t2-tOffs)*tScale)
					else
						col1 = colorDict[colorBy[r]]
						col2 = colorDict[colorBy[c]]
					end

					colorsRGB[lineInd]   = col1
					colorsRGB[lineInd+1] = col2

					lineInd+=3
				end
			end
			@assert lineInd == nbrLines*3+1

			if size(V,2)==2
				# PLOTLY DOESN'T HANDLE PER VERTEX COLORS FOR 2D LINES. THIS IS A STUPID WORKAROUND TO MAKE LINES BLACK IN 2D.
				push!(traces, _scatter(VL; mode="lines", line=attr(color=colorant"black", width=lineWidth), showlegend=false))
			else
				push!(traces, _scatter(VL; mode="lines", line=attr(color=colorsRGB, width=lineWidth), showlegend=false))
			end
		end
	end

	# plot each group in different colors
	if drawPoints
		# TODO: merge the two cases below?

		if colorDict != nothing
			for cb in unique(colorBy)
				ind = findall(colorBy.==cb )
				col = colorDict[cb]

				extras = []
				length(colorDict)==1 && push!(extras, (;showlegend=false))
				shapeBy!=nothing && shapeDict!=nothing && push!(extras, (marker_symbol=[shapeDict[k] for k in shapeBy[ind]],))
				isempty(extras) || (extras = pairs(extras...))

				points = _scatter(V[ind,:]; mode="markers", marker_color=col, marker_size=markerSize, marker_line_width=0, name=string(cb), extras...)
				push!(traces, points)
			end
		else
			extras = []
			shapeBy!=nothing && shapeDict!=nothing && push!(extras, (marker_symbol=[shapeDict[k] for k in shapeBy],))
			isempty(extras) || (extras = pairs(extras...))

			V2 = V
			c = colorBy

			# handle missing values by plotting them in another trace (with a different color)
			if any(ismissing, c)
				mask = ismissing.(c)
				pointsNA = _scatter(V2[mask,:]; mode="markers", marker=attr(color=colorant"black", size=markerSize, line_width=0), name="", showlegend=false, extras...)
				push!(traces, pointsNA)

				V2 = V2[.!mask,:]
				c = disallowmissing(c[.!mask])
			end

			points = _scatter(V2; mode="markers", marker=attr(color=c, colorscale=to_list(colorScale), showscale=true, size=markerSize, line_width=0, colorbar=attr(title=legendTitle)), name="", showlegend=false, extras...)
			push!(traces, points)
		end
	end

	if size(V,2)==2
		layout = Layout(title=title,
		                xaxis=attr(title=xLabel, constrain="domain"),
		                yaxis=attr(title=yLabel, constrain="domain", scaleanchor='x'),
		                legend=attr(title_text=legendTitle, itemsizing="constant"),
		                hovermode="closest")
	else
		layout = Layout(title=title,
		                scene=attr(xaxis=attr(title=xLabel), yaxis=attr(title=yLabel), zaxis=attr(title=zLabel), camera=cameraAttr, aspectmode="data"),
		                legend=attr(title_text=legendTitle, itemsizing="constant"))
	end
	traces, layout # return plot args rather than plot because of threading issues.
end

_distinguishable_colors(n) = distinguishable_colors(n+1,colorant"white")[2:end]

function colordict(x::AbstractArray)
	k = unique(x)
	Dict(s=>c for (s,c) in zip(k,_distinguishable_colors(length(k))))
end


struct ColorScale
	t::Vector{Float64} # increasing values between 0 and 1. First must be 0 and last must be 1.
	colors::Vector{RGB{Float64}} # must be same length as t
end
to_list(colorScale::ColorScale) = [ [t,c] for (t,c) in zip(colorScale.t, colorScale.colors)]

function lookup(colorScale::ColorScale, t::Float64)
	i2 = searchsortedfirst(colorScale.t, t)
	i2>length(colorScale.t) && return colorScale.colors[end]
	i2==1 && return colorScale.colors[1]
	i1 = i2-1
	α = (t-colorScale.t[i1]) / (colorScale.t[i2]-colorScale.t[i1])
	weighted_color_mean(α, colorScale.colors[i2], colorScale.colors[i1]) # NB: order because α=1 means first color in weighted_color_mean
end



const SHAPES = ["circle","square","diamond","cross","x","triangle-up","triangle-down","triangle-left","triangle-right","triangle-ne","triangle-se","triangle-sw","triangle-nw","pentagon","hexagon","hexagon2","octagon","star","hexagram","star-triangle-up","star-triangle-down","star-square","star-diamond","diamond-tall","diamond-wide","hourglass","bowtie","circle-cross","circle-x","square-cross","square-x","diamond-cross","diamond-x","cross-thin","x-thin","asterisk","hash","y-up","y-down","y-left","y-right","line-ew","line-ns","line-ne","line-nw","circle-open","square-open","diamond-open","cross-open","x-open","triangle-up-open","triangle-down-open","triangle-left-open","triangle-right-open","triangle-ne-open","triangle-se-open","triangle-sw-open","triangle-nw-open","pentagon-open","hexagon-open","hexagon2-open","octagon-open","star-open","hexagram-open","star-triangle-up-open","star-triangle-down-open","star-square-open","star-diamond-open","diamond-tall-open","diamond-wide-open","hourglass-open","bowtie-open","circle-cross-open","circle-x-open","square-cross-open","square-x-open","diamond-cross-open","diamond-x-open","cross-thin-open","x-thin-open","asterisk-open","hash-open","y-up-open","y-down-open","y-left-open","y-right-open","line-ew-open","line-ns-open","line-ne-open","line-nw-open","","circle-dot","square-dot","diamond-dot","cross-dot","x-dot","triangle-up-dot","triangle-down-dot","triangle-left-dot","triangle-right-dot","triangle-ne-dot","triangle-se-dot","triangle-sw-dot","triangle-nw-dot","pentagon-dot","hexagon-dot","hexagon2-dot","octagon-dot","star-dot","hexagram-dot","star-triangle-up-dot","star-triangle-down-dot","star-square-dot","star-diamond-dot","diamond-tall-dot","diamond-wide-dot","hash-dot","circle-open-dot","square-open-dot","diamond-open-dot","cross-open-dot","x-open-dot","triangle-up-open-dot","triangle-down-open-dot","triangle-left-open-dot","triangle-right-open-dot","triangle-ne-open-dot","triangle-se-open-dot","triangle-sw-open-dot","triangle-nw-open-dot","pentagon-open-dot","hexagon-open-dot","hexagon2-open-dot","octagon-open-dot","star-open-dot","hexagram-open-dot","star-triangle-up-open-dot","star-triangle-down-open-dot","star-square-open-dot","star-diamond-open-dot","diamond-tall-open-dot","diamond-wide-open-dot","hash-open-dot"]
shapedict(x::AbstractArray) = Dict(v=>SHAPES[mod(i-1,length(SHAPES))+1] for (i,v) in enumerate(unique(x)))
