(() => {
	const hint = document.getElementById('hint');

	const el = (tag, cls, text) => {
		const node = document.createElement(tag);
		if (cls) node.className = cls;
		if (text !== undefined) node.textContent = text;
		return node;
	};

	window.addEventListener('message', ({ data }) => {
		if (!data) return;

		if (data.action === 'hint') {
			hint.replaceChildren(el('span', 'hint-main', data.main));
			const keys = el('span', 'hint-keys');
			(data.keys || []).forEach(([key, label]) => {
				const item = el('span');
				item.append(el('b', '', key), document.createTextNode(label));
				keys.append(item);
			});
			hint.append(keys);
			hint.classList.remove('hidden');
		} else if (data.action === 'hintHide') {
			hint.classList.add('hidden');
		}
	});
})();
