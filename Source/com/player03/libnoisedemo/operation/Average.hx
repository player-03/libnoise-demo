package com.player03.libnoisedemo.operation;

import libnoise.ModuleBase;

/**
 * Averages the output of two source modules.
 */
class Average extends ModuleBase {
	public function new(lhs:ModuleBase, rhs:ModuleBase) {
		super(2);
		set(0, lhs);
		set(1, rhs);
	}

	public override function getValue(x:Float, y:Float, z:Float):Float {
		var val1 = get(0).getValue(x, y, z);
		var val2 = get(1).getValue(x, y, z);
		return (val1 + val2) / 2;
	}
}
