.pragma library

// Pure parsers for the procfs files Sysmon reads. Output matches the JSON the
// old python sampler printed: { cpu, cores, mem, freq, net, route }.

function nums(line) {
	const parts = line.trim().split(/\s+/)
	const out = []
	for (let i = 1; i < parts.length; i++)
		out.push(parseInt(parts[i], 10) || 0)
	return out
}

// /proc/stat: aggregate "cpu" line, then cpuN lines until the first non-core line.
function parseStat(text) {
	const lines = String(text || "").split("\n")
	const result = { cpu: [], cores: [] }
	if (!lines.length || !lines[0].startsWith("cpu"))
		return result
	result.cpu = nums(lines[0])
	for (let i = 1; i < lines.length; i++) {
		const line = lines[i]
		if (line.startsWith("cpu") && line.length > 3 && line[3] >= "0" && line[3] <= "9")
			result.cores.push(nums(line))
		else
			break
	}
	return result
}

// /proc/meminfo: "Key:   12345 kB" -> { Key: 12345 } (kB, as before).
function parseMeminfo(text) {
	const mem = {}
	const lines = String(text || "").split("\n")
	for (let i = 0; i < lines.length; i++) {
		const colon = lines[i].indexOf(":")
		if (colon <= 0)
			continue
		const value = parseInt(lines[i].slice(colon + 1).trim().split(/\s+/)[0], 10)
		if (!isNaN(value))
			mem[lines[i].slice(0, colon).trim()] = value
	}
	return mem
}

// /proc/net/route: interface of the first default route.
function parseRoute(text) {
	const lines = String(text || "").split("\n")
	for (let i = 0; i < lines.length; i++) {
		const p = lines[i].trim().split(/\s+/)
		if (p.length > 1 && p[0] !== "Iface" && p[1] === "00000000")
			return p[0]
	}
	return ""
}

// /proc/net/dev: per-interface rx/tx byte counters, loopback skipped.
function parseNetDev(text) {
	const net = {}
	const lines = String(text || "").split("\n")
	for (let i = 0; i < lines.length; i++) {
		const colon = lines[i].indexOf(":")
		if (colon < 0)
			continue
		const name = lines[i].slice(0, colon).trim()
		if (!name || name === "lo")
			continue
		const cols = lines[i].slice(colon + 1).trim().split(/\s+/)
		if (cols.length < 9)
			continue
		net[name] = { rx: parseInt(cols[0], 10) || 0, tx: parseInt(cols[8], 10) || 0 }
	}
	return net
}

function parseFreq(text) {
	const n = parseInt(String(text || "").trim(), 10)
	return n > 0 ? n : 0
}

function sample(statText, memText, freqText, routeText, netText) {
	const stat = parseStat(statText)
	return {
		cpu: stat.cpu,
		cores: stat.cores,
		mem: parseMeminfo(memText),
		freq: parseFreq(freqText),
		net: parseNetDev(netText),
		route: parseRoute(routeText)
	}
}
