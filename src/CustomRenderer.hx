package ;

import ds.aabbtree.Node;
import ds.aabbtree.OpenFLRenderer;
import flash.display.Graphics;


/**
 * Custom debug renderer for AABBTree.
 * 
 * @author azrafe7
 */
class CustomRenderer<T> extends OpenFLRenderer<T>
{

	// draw tree up to this level.
	public var maxLevel:Int = 1000000;
	
	// draw only leaf nodes.
	public var leafOnly:Bool = true;

	
	public function new(g:Graphics) 
	{
		super(g);
	}
	
	override public function drawNode(node:Node<T>, isLeaf:Bool, level:Int):Void 
	{
		if (leafOnly && isLeaf) {
			var tmp = connectToParent;
			connectToParent = false;
			super.drawNode(node, isLeaf, level);
			connectToParent = tmp;
		} else if (!leafOnly && level <= maxLevel) {
			super.drawNode(node, isLeaf, level);
		}
	}
}