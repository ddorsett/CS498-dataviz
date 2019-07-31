const stationList = {
	["USW00014764"]: "Portland, ME",
	["USW00014739"]: "Boston, MA",
	["USW00094789"]: "New York City, NY",
	["USW00013739"]: "Philadelphia, PA",
	["USW00093721"]: "Baltimore, MD",
	["USW00013750"]: "Norfolk, VA",
	["USW00013748"]: "Wilmington, NC",
	["USW00013782"]: "Charleston, SC",
	["USC00084366"]: "Jacksonville, FL",
	["USW00092811"]: "Miami, FL"
}

function linearFit(xSeries, ySeries) {
	let sum = function (p, c) {
		return p + c
	}
	let xBar = xSeries.reduce(sum) * 1.0 / xSeries.length
	let yBar = ySeries.reduce(sum) * 1.0 / ySeries.length
	let ssXX = xSeries.map(function (d) {
		return (d - xBar) * (d - xBar)
	}).reduce(sum)
	let ssYY = ySeries.map(function (d) {
		return (d - yBar) * (d - yBar)
	}).reduce(sum)
	let ssXY = xSeries.map(function (d, i) {
		return (d - xBar) * (ySeries[i] - yBar)
	}).reduce(sum)
	let m = ssXY / ssXX
	let b = yBar - (xBar * m)
	return (x => {
		return (m * x) + b
	})
}

async function drawSeasonTemp(parentSelector, replace, stations, season, startYear, highTemp, showActuals, animate, showEvents, showAnnotations, showTrend) {
	const baseline = await d3.csv('http://localhost/data/season_baseline.csv')
	let data = await d3.csv('http://localhost/data/seasons.csv')
	let events = await d3.csv('http://localhost/data/events.csv')
	let anndata = await d3.csv('http://localhost/data/annotations.csv')

	data = data.filter(d => Number(d.YEAR) >= startYear && d.SEASON === season)
	events = events.filter(d => {return (Number(d.YEAR) >= startYear && d.SEASON === season && d.TYPE === (highTemp ? "TMAX" : "TMIN"))})

	const margin = {
			top: 50,
			right: 20,
			bottom: 20,
			left: 20
		},
		width = 1000 - margin.left - margin.right,
		height = 200
	let x = d3.scaleTime().range([0, width]).domain([new Date(startYear, 0), new Date(2018, 11)])
	let y = d3.scaleLinear().range([height, 0]).domain([-10, 10])
	let xAxis = d3.axisBottom().scale(x)
	let yAxis = d3.axisLeft().scale(y).ticks(5)
	let tooltip = d3.select("#tooltip")

	let line = d3.line()
		.x(d => { return x(d.date) })
		.y(d => { return y(d.temp) })
		.defined(d => { return d != -999 })

	let svg

	for (let s = 0; s < stations.length; s++) {
		let station = stations[s]
		let sdata = data.filter(d => d.STATION === station)
		let tempBaseline = 0
		for (let i = 0; i < baseline.length; i++) {
			if (baseline[i].STATION === station && baseline[i].SEASON === season) {
				tempBaseline = highTemp ? baseline[i].TMAX_MEAN : baseline[i].TMIN_MEAN
				break
			}
		}
		let anomalyData = []
		for (let i = 0; i < sdata.length; i++) {
			anomalyData.push({
				date: new Date(sdata[i].YEAR, 0),
				year: Number(sdata[i].YEAR),
				temp: Number((highTemp ? sdata[i].TMAX_MEAN : sdata[i].TMIN_MEAN) - tempBaseline),
				abs: Number(highTemp ? sdata[i].TMAX_MEAN : sdata[i].TMIN_MEAN)
			})
		}
		let edata = events.filter(d => d.STATION === station)

		// create annotation data structure
		let annotations = [], up = 1
		for (let a = 0; a < anndata.length; a++) {
			if (anndata[a].SEASON === season) {
				annotations.push({
					note: {	label: anndata[a].TEXT },
					data: { YEAR: Number(anndata[a].YEAR), up: up },
					className: "annotation",
					dy: up*50,
					dx: 0,
					connector: { end: "arrow" }
				})
				up *= -1
			}
		}

		// is there already a chart in the parent?? If so, replace it
		let existing = !d3.select(parentSelector + " div").empty()
		if (replace && existing) {
			d3.select(parentSelector + " div").remove()
		}
		svg = d3.select(parentSelector)
			.append('div').attr('id', station).attr('class', 'station')
			.append('svg')
			.attr('width', width + margin.left + margin.right)
			.attr('height', height + margin.top + margin.bottom)
		let bounds = svg.append('g').attr('transform', `translate(${margin.left},${margin.top})`)

		if (showActuals) {
			let tooltipCircle = bounds.append("circle").attr("r", 4).attr("stroke", "#af9358").attr("fill", "white").attr("stroke-width", 2).style("opacity", 0)
			let overlay = bounds.append('rect')
				.attr("class", "overlay")
				.attr("width", width)
				.attr("height", height)
				.on("mousemove", function onMove() {
					const mousePosition = d3.mouse(this)
					const mouseDate = x.invert(mousePosition[0])
					const closestIndex = d3.scan(anomalyData, (a, b) => (
						Math.abs(a.date - mouseDate) - Math.abs(b.date - mouseDate)
					))
					if (closestIndex > -1) {
						tooltip.select("#tooltip-date").text(anomalyData[closestIndex].year)
						tooltip.select("#tooltip-message").text(`Anomoly: ${anomalyData[closestIndex].temp.toFixed(2)} °F`)
						tooltip.select("#tooltip-message2").text(`Average Temperature:${anomalyData[closestIndex].abs.toFixed(1)} °F`)
						tooltip.style("left", (d3.event.pageX)+"px")
						tooltip.style("top", (d3.event.pageY)+"px")
						tooltipCircle.attr("cx", x(anomalyData[closestIndex].date)).attr("cy", y(anomalyData[closestIndex].temp)).style("opacity", 1)
						tooltip.style("opacity", 0.85)
					}
				})
				.on("mouseleave", function onLeave() {
					tooltip.style("opacity", 0)
					tooltipCircle.style("opacity", 0)
				})
		}

		// axes and zero-line
		let x1 = new Date(startYear, 0)
		let x2 = new Date(2018, 0)
		let yearWidth = x(x2) - x(new Date(2017, 0))
		bounds.append("g")
			.attr("class", "x axis")
			.attr("transform", "translate(0," + height + ")")
			.call(xAxis)
		bounds.append("g")
			.attr("class", "y axis")
			.call(yAxis)
		bounds.append("text")
			.attr("x", (width / 2))
			.attr("y", 0 - (margin.top / 2))
			.attr("text-anchor", "middle")
			.style("font-size", "0.9rem")
			.style("font-family", "Arial, Helvetica, sans-serif")
			.text(`${stationList[station]} Average ${season[0].toUpperCase()}${season.substring(1)} ${highTemp ? 'High' : 'Low'} Temperature Anomalies from ${startYear} to 2019`);
		bounds.selectAll(".zeroline").data([[x1, 0, x2, 0]]).enter()
			.append("line")
			.attr("class", "zeroline")
			.attr("x1", d => { return x(d[0]) })
			.attr("y1", d => { return y(d[1]) })
			.attr("x2", d => { return x(d[2]) })
			.attr("y2", d => { return y(d[3]) })
			.attr("stroke-dasharray", "5,5")

		if (showEvents) {
			bounds.selectAll(".event").data(edata).enter().append("circle")
				.attr("cx", d => { return x(new Date(d.YEAR, 0)) })
				.attr("cy", y(0))
				.attr("r", d => { return yearWidth/30.0 * d.COUNT })
				.attr("fill", "red").style("opacity", .5)
				.on("mouseover", function(d, i) {
					tooltip.style("opacity", 0.85)
						.style("left", (d3.event.pageX)+"px")
						.style("top", (d3.event.pageY)+"px")
					tooltip.select("#tooltip-date").text(d.YEAR)
					tooltip.select("#tooltip-message").text(`${d.EVENT} of ${d.LABEL}`)
				})
				.on("mouseout", function() { tooltip.style("opacity", 0) })
		}

		// graph the least squares regression
		if (showTrend) {
			let fit = linearFit(anomalyData.map(x => {
				return x.year
			}), anomalyData.map(x => {
				return x.temp
			}))
			let y1 = fit(startYear) // TODO: or 1969???
			let y2 = fit(2018)
			let trendline = bounds.selectAll(".trendline").data([[x1, y1, x2, y2]]).enter()
				.append("line")
				.attr("class", "trendline")
				.attr("x1", d => { return x(d[0]) })
				.attr("y1", d => { return y(d[1]) })
				.attr("x2", d => { return x(d[2]) })
				.attr("y2", d => { return y(d[3]) })
				.attr("stroke-dasharray", "10,10")
		}

		if (showActuals) {
			let path = bounds.append("path").datum(anomalyData).attr("class", "templine " + season).attr("id", "p"+station).attr("d", line)
			if (animate) {
				let pathSel = document.querySelector('#p' + station)
				let totalLength = pathSel.getTotalLength()
				path.attr("stroke-dasharray", totalLength + " " + totalLength)
					.attr("stroke-dashoffset", totalLength)
					.transition()
					.ease(d3.easeLinear)
					.duration(3000)
					.attr("stroke-dashoffset", 0)
			}
		}

		if (showAnnotations) {
			const makeAnnotations = d3.annotation()
				.textWrap(90)
				.type(d3.annotationLabel)
				.annotations(annotations)
				.accessors({
					x: d => { return x(new Date(d.YEAR, 0)) },
					y: d => { return y(0) }
				})
			bounds.append("g").call(makeAnnotations)
		}
	}
	return svg
}

async function drawSeasonPrecip(parentSelector, replace, stations, season, startYear, showActuals, animate, showEvents) {
	const baseline = await d3.csv('http://localhost/data/season_baseline.csv')
	let data = await d3.csv('http://localhost/data/seasons.csv')
	let events = await d3.csv('http://localhost/data/events.csv')

	data = data.filter(d => Number(d.YEAR) >= startYear && d.SEASON === season)
	events = events.filter(d => Number(d.YEAR) >= startYear && d.SEASON === season && d.TYPE === "PRCP")
	let maxY = Math.ceil(Math.max(...data.map(d => { return parseFloat(d.PRCP_TOTAL) }))/5) * 5

	const margin = {
			top: 20,
			right: 20,
			bottom: 20,
			left: 20
		},
		width = 1000 - margin.left - margin.right,
		height = 200
	let x = d3.scaleBand().range([0, width]).domain(d3.range(startYear, 2019))
	let y = d3.scaleLinear().range([height, 0]).domain([0, Math.round(maxY)])
	let xAxis = d3.axisBottom().scale(x).tickValues(x.domain().filter((d,i) => { return !(d%5)}))
	let yAxis = d3.axisLeft().scale(y).ticks(5)
	let tooltip = d3.select("#tooltip")

	for (let s = 0; s < stations.length; s++) {
		let station = stations[s]

		// is there already a chart in the parent?? If so, replace it
		let existing = !d3.select(parentSelector + " div").empty()
		if (replace && existing) {
			d3.select(parentSelector + " div").remove()
		}
		let svg = d3.select(parentSelector).append('div').attr('id', station).attr('class', 'station')
			.append("svg")
			.attr("width", width + margin.left + margin.right)
			.attr("height", height + margin.top + margin.bottom)
			.append("g")
			.attr("transform", "translate(" + margin.left + "," + margin.top + ")")

		let sdata = data.filter(d => d.STATION === station)
		let edata = events.filter(d => d.STATION === station)

		let prcpBaseline = 0
		for (let i = 0; i < baseline.length; i++) {
			if (baseline[i].STATION === station && baseline[i].SEASON === season) {
				prcpBaseline = baseline[i].PRCP_MEAN
				break
			}
		}
		let prcpData = []
		for (let i = 0; i < sdata.length; i++) {
			prcpData.push({
				date: new Date(sdata[i].YEAR, 0),
				year: Number(sdata[i].YEAR),
				rain: Number(sdata[i].PRCP_TOTAL)
			})
		}

		// axes and zero-line
		svg.append("g")
			.attr("class", "x axis")
			.attr("transform", "translate(0," + height + ")")
			.call(xAxis)
		svg.append("g")
			.attr("class", "y axis")
			.call(yAxis)
		svg.append("text")
			.attr("x", (width / 2))
			.attr("y", 0 - (margin.top / 2))
			.attr("text-anchor", "middle")
			.style("font-size", "0.9rem")
			.style("font-family", "Arial, Helvetica, sans-serif")
			.text(`${stationList[station]} Total ${season[0].toUpperCase()}${season.substring(1)} Precipitation from ${startYear} to 2019`);

		if (showActuals) {
			let bars = svg.selectAll(".bar").data(prcpData).enter().append("rect")
				.attr("class", (d => {
					return (d.rain > prcpBaseline) ? 'highprecip' : 'precip'
				}))
				.attr("x", d => { return x(d.year) })
				.attr("width", x.bandwidth())
				.on("mouseover", function(d, i) {
					tooltip.style("opacity", 0.85)
						.style("left", (d3.event.pageX)+"px")
						.style("top", (d3.event.pageY)+"px")
				tooltip.select("#tooltip-date").text(d.year)
				tooltip.select("#tooltip-message").text(`Total rainfall: ${d.rain.toFixed(1)} inches`)
				})
				.on("mouseout", function() { tooltip.style("opacity", 0) })

			if (animate) {
				bars.attr("y", function(d) { return height })
					.attr("height", 0)
					.transition()
					.duration(50)
					.delay(function (d, i) { return i * 50 })
					.attr("y", d => { return y(d.rain) } )
					.attr("height", d => { return height - y(d.rain) })
			} else {
				bars.attr("y", d => { return y(d.rain) })
					.attr("height", d => { return height - y(d.rain) })
			}
		}
		svg.selectAll(".zeroline").data([[startYear, prcpBaseline, 2018, prcpBaseline]]).enter().append("line")
			.attr("class", "zeroline")
			.attr("x1", d => { return x(d[0]) })
			.attr("y1", d => { return y(d[1]) })
			.attr("x2", d => { return x(d[2]) })
			.attr("y2", d => { return y(d[3]) })
			.attr("stroke-dasharray", "5,5")
		let lastYear, lastSide = 1, kick = 0

		if (showEvents) {
			let stormCirle = svg.selectAll(".event").data(edata).enter().append("circle")
				.attr("cx", d => { return x(d.YEAR)+x.bandwidth()/2 })
				.attr("cy", y(prcpBaseline))
				.attr("r", d => { return 5*d.COUNT }).attr("fill", d => { return d.EVENT === 'Hurricane' ? "red" : "yellow" }).style("opacity", 1)
				.on("mouseover", function(d, i) {
					tooltip.style("opacity", 0.85)
						.style("left", (d3.event.pageX)+"px")
						.style("top", (d3.event.pageY)+"px")
				tooltip.select("#tooltip-date").text(d.YEAR)
				tooltip.select("#tooltip-message").text(`${d.EVENT} ${d.LABEL}`)
				})
				.on("mouseout", function() { tooltip.style("opacity", 0) })
			if (animate) {
				repeatSwell()
			}

			function repeatSwell() {
				stormCirle.attr("r", d => { return 5*d.COUNT }).attr("fill", d => { return d.EVENT === 'Hurricane' ? "red" : "yellow" }).style("opacity", 1)
					.transition()
					.duration(2000)
					.attr("r", d => { return d.EVENT === 'Hurricane' ? 20*d.COUNT : 10*d.COUNT }).attr("fill", d => { return d.EVENT === 'Hurricane' ? "red" : "yellow" }).style("opacity", 1)
					.transition()
					.duration(2000)
					.attr("r", 5).attr("fill", d => { return d.EVENT === 'Hurricane' ? "red" : "yellow" }).style("opacity", 1)
					.on("end", repeatSwell)
			}

			svg.selectAll(".eventtext").data(edata).enter()
				.append("text")
				.attr("x", d => { return x(d.YEAR)+x.bandwidth()/2 })
				.attr("y", (d,i) => {
					let offset = 0
					if (Number(d.YEAR) < lastYear + 3 && Number(d.YEAR) > lastYear - 3) {
						if (lastSide == i%2) {
							kick += i%2
						}
						offset = (15 * kick)
					} else {
						kick = 0
					}
					if (i%2) {
						lastYear = Number(d.YEAR), lastSide = i%2
					}
					return (i%2) ? y(prcpBaseline)+15+offset : y(prcpBaseline)-15-offset })
				.attr("class", "event-text")
				.attr("fill", "blue")
				.text(d => { return d.LABEL })
		}
	}
}