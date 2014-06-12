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
class OpenFLRenderer extends DebugRenderer
{
	var g:Graphics;
	
	var colorByLevel:Int->Int;
	var leafColor:Int;
	var alpha:Int;
	var connectToParent:Bool;
	
	var colorMap:Array<Int> = [0xFF0000];

	
	/**
	 * Creates a new debug renderer using OpenFL.
	 * 
	 * @param	g					The graphics to be uses to render the tree.
	 * @param	colorByLevel		A function mapping a level of the tree to the color to be used to draw the related aabbs.
	 * @param	leafColor			Color to use to draw the leaf aabbs.
	 * @param	alpha				Alpha value to use when drawing aabbs.
	 * @param	connectToParent		Wether a line should be drawn that connects children to their parent aabbs.
	 */
	public function new(g:Graphics, ?colorByLevel:Int->Int, leafColor:Int = 0x808080, alpha:Float = .6, connectToParent:Bool = true) 
	{
		this.g = g;
		this.colorByLevel != null ? colorByLevel : _colorByLevel;
		this.leafColor = leafColor;
		this.alpha = alpha;
		this.connectToParent = connectToParent;
	}
	
	override public function drawAABB(aabb:AABB, isLeaf:Bool, level:Int):Void 
	{
		var color = isLeaf ? leafColor : colorByLevel(level);
		
		g.lineStyle(1, color, alpha);
		if (isLeaf) g.beginFill(color);
		g.drawRect(aabb.x, aabb.y, aabb.width, aabb.height);
		if (isLeaf) g.endFill();
	}
	
	override public function drawNode(node:Node<T>, isLeaf:Bool, level:Int):Void 
	{
		super.drawNode(node, isLeaf, level);
		if (connectToParent) {
			var color = isLeaf ? leafColor : colorByLevel(level);
			if (parent != null) {
				g.lineStyle(1, color);
				g.moveTo(node.aabb.x, node.aabb.y);
				g.lineTo(node.parent.x, node.parent.y);
			}
		}
	}
	
	private function _colorByLevel(level:Int):Int 
	{
		if (colorMap.length <= level) {
			colorMap[level] = randomColor(colorMap[0]);
		}
		
		return colorMap[level];
	}
	
	// from http://stackoverflow.com/questions/43044/algorithm-to-randomly-generate-an-aesthetically-pleasing-color-palette
	private function randomColor(color:Int):Int
	{
		var r = Std.int(Math.random() * 256);
		var g = Std.int(Math.random() * 256);
		var b = Std.int(Math.random() * 256);

		r = (r + ((color >> 16) & 0xFF)) >> 1;
		g = (g + ((color >> 8) & 0xFF)) >> 1;
		b = (b + (color & 0xFF)) >> 1;
		
		return ((r << 16) | (g << 8) | b);
	}
}