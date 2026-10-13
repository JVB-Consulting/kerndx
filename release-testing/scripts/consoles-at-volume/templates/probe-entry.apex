// Consoles at volume: one INFO entry preflight looks for, to prove the org persists INFO. Tokens: __APEX_NAMESPACE__ __TOKEN__
__APEX_NAMESPACE__LOG_Builder.build().info('Consoles at volume preflight __TOKEN__').emitAt('ConsolesAtVolume.preflight');
System.debug('VOLUME_PREFLIGHT emitted=__TOKEN__');
