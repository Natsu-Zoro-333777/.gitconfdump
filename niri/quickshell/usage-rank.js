.pragma library

// Launcher order: up to `limit` apps with a positive usage score first (highest
// score first), then everything else alphabetically by title.
function rank(items, scoreOf, limit) {
	const byTitle = (a, b) => a.title.localeCompare(b.title)
	const scored = []
	for (let i = 0; i < items.length; i++) {
		const s = scoreOf(items[i].id)
		if (s > 0)
			scored.push({ item: items[i], score: s })
	}
	scored.sort((a, b) => (b.score - a.score) || byTitle(a.item, b.item))
	const top = scored.slice(0, Math.max(0, limit))
	const promoted = {}
	const out = []
	for (let i = 0; i < top.length; i++) {
		promoted[top[i].item.id] = true
		out.push(top[i].item)
	}
	const rest = []
	for (let i = 0; i < items.length; i++) {
		if (!promoted[items[i].id])
			rest.push(items[i])
	}
	rest.sort(byTitle)
	return out.concat(rest)
}
