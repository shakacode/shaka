const stateType = 'shaka.session-name';

function result(pi, status) {
  const details = { name: pi.getSessionName() ?? null, status };
  return { content: [{ type: 'text', text: JSON.stringify(details) }], details };
}

export default function (pi) {
  pi.registerTool({
    name: 'shaka_session_name',
    label: 'Shaka session name',
    description: 'Read the actual Pi session name, or apply a Shaka workflow title while preserving user-chosen names.',
    parameters: {
      type: 'object',
      properties: { name: { type: 'string', description: 'Desired single-line workflow title; omit to read the current name.' } },
      additionalProperties: false,
    },
    executionMode: 'sequential',
    async execute(_id, params, _signal, _onUpdate, ctx) {
      if (params.name === undefined) return result(pi, 'read');
      const name = params.name.trim();
      if (!name || /[\r\n]/.test(name)) throw new Error('Session name must be nonempty and single-line.');
      const current = pi.getSessionName();
      if (name === current) return result(pi, 'unchanged');

      // Session names are global metadata, so ownership follows all entries, not just the active branch.
      const state = ctx.sessionManager.getEntries().findLast(
        entry => entry.type === 'custom' && entry.customType === stateType,
      )?.data;
      if (current && state?.name === current && state.isDeclined) return result(pi, 'preserved');
      if (current && state?.name !== current) {
        if (!ctx.hasUI) return result(pi, 'preserved');
        const isApproved = await ctx.ui.confirm('Rename this Pi session?', `Replace “${current}” with “${name}”?`);
        if (!isApproved) {
          pi.appendEntry(stateType, { name: current, isDeclined: true });
          return result(pi, 'preserved');
        }
      }
      pi.setSessionName(name);
      pi.appendEntry(stateType, { name: pi.getSessionName(), isDeclined: false });
      return result(pi, 'renamed');
    },
  });
}
