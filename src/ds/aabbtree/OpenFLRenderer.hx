/*
 * This file is part of the AABBTree library for haxe (https://github.com/azrafe7/AABBTree).
 *
 * Developed by Giuseppe Di Mauro (aka azrafe7) and realeased under the MIT license (see LICENSE file).
 */

package ds.aabbtree;

import ds.AABB;
import flash.display.Graphics;


/**
 * AABBTree debug renderer using OpenFL.
 * 
 * @author azrafe7
 */
class OpenFLRenderer<T> extends DebugRenderer<T>
{
	var g:Graphics;
	
	var colorByLevel:Int->Int;
	var leafColor:Int;
	var leafAlpha:Float;
	var internalAlpha:Float;
	var connectToParent:Bool;
	
	var colorMap:Map<Int, Int> = [0 => 0xFF0000];
	var HSV:Array<Float> = [.1, .9, 1];

	
	/**
	 * Creates a new debug renderer using OpenFL.
	 * 
	 * @param	g					The graphics to be uses to render the tree.
	 * @param	colorByLevel		A function mapping a level of the tree to the color to be used to draw the related aabbs.
	 * @param	leafColor			Color to use to draw the leaf aabbs.
	 * @param	leafAlpha			Alpha value to use when drawing leaf aabbs.
	 * @param	internalAlpha		Alpha value to use when drawing non-leaf aabbs.
	 * @param	connectToParent		Wether a line should be drawn that connects children to their parent aabbs.
	 */
	public function new(g:Graphics, ?colorByLevel:Int->Int, leafColor:Int = 0xFFFFFF, leafAlpha:Float = .1, internalAlpha:Float = .7, connectToParent:Bool = true) 
	{
		super();
		this.g = g;
		this.colorByLevel = colorByLevel != null ? colorByLevel : _colorByLevel;
		this.leafColor = leafColor;
		this.leafAlpha = leafAlpha;
		this.internalAlpha = internalAlpha;
		this.connectToParent = connectToParent;
	}
	
	override public function drawAABB(aabb:AABB, isLeaf:Bool, level:Int):Void 
	{
		var color = isLeaf ? leafColor : colorByLevel(level);
		
		g.lineStyle(isLeaf ? 1 : 2, color, isLeaf ? leafAlpha : internalAlpha);
		if (isLeaf) g.beginFill(color, leafAlpha);
		g.drawRect(aabb.x, aabb.y, aabb.width, aabb.height);
		if (isLeaf) g.endFill();
	}
	
	override public function drawNode(node:Node<T>, isLeaf:Bool, level:Int):Void 
	{
		super.drawNode(node, isLeaf, level);
		if (connectToParent) {
			var color = isLeaf ? leafColor : colorByLevel(level);
			if (node.parent != null) {
				g.lineStyle(1, color, internalAlpha);
				g.moveTo(node.aabb.x, node.aabb.y);
				g.lineTo(node.parent.aabb.x, node.parent.aabb.y);
				g.drawCircle(node.parent.aabb.x, node.parent.aabb.y, 2);
			}
		}
	}
	
	private function _colorByLevel(level:Int):Int 
	{
		if (colorMap.get(level) == null) {
			HSV[0] = (HSV[0] + .12) % 1.0;
			colorMap[level] = getColorFromHSV(HSV[0], HSV[1], HSV[2]);
		}
		
		return colorMap[level];
	}
	
	private function getColorFromHSV(h:Float, s:Float, v:Float):Int
	{
		h = Std.int(h * 360);
		var hi:Int = Math.floor(h / 60) % 6,
			f:Float = h / 60 - Math.floor(h / 60),
			p:Float = (v * (1 - s)),
			q:Float = (v * (1 - f * s)),
			t:Float = (v * (1 - (1 - f) * s));
		switch (hi)
		{
			case 0: return Std.int(v * 255) << 16 | Std.int(t * 255) << 8 | Std.int(p * 255);
			case 1: return Std.int(q * 255) << 16 | Std.int(v * 255) << 8 | Std.int(p * 255);
			case 2: return Std.int(p * 255) << 16 | Std.int(v * 255) << 8 | Std.int(t * 255);
			case 3: return Std.int(p * 255) << 16 | Std.int(q * 255) << 8 | Std.int(v * 255);
			case 4: return Std.int(t * 255) << 16 | Std.int(p * 255) << 8 | Std.int(v * 255);
			case 5: return Std.int(v * 255) << 16 | Std.int(p * 255) << 8 | Std.int(q * 255);
			default: return 0;
		}
		return 0;
	}
}