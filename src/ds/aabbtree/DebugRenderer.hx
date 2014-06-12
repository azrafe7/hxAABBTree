/*
 * This file is part of the AABBTree library for haxe (https://github.com/azrafe7/AABBTree).
 *
 * Developed by Giuseppe Di Mauro (aka azrafe7) and realeased under the MIT license (see LICENSE file).
 */

package ds.aabbtree;


import ds.AABB;


interface IDebugRenderer<T>
{
	function drawAABB(aabb:AABB, isLeaf:Bool, level:Int):Void;
	
	function drawNode(node:Node<T>, isLeaf:Bool, level:Int):Void;
	
	function drawTree(tree:AABBTree<T>):Void;
}

/**
 * Extend this class and override its methods to implement a custom AABBTree renderer.
 * 
 * @author azrafe7
 */
class DebugRenderer<T> implements IDebugRenderer<T>
{

	public function new() 
	{
		
	}
	
	/** Draw the `aabb`. `isLeaf` will be true if the `aabb` belongs to a leaf node. `level` will be zero if `node` is the root (> 0 otherwise).*/
	public function drawAABB(aabb:AABB, isLeaf:Bool, level:Int):Void
	{
		
	}
	
	/** Draw a `node`. `isLeaf` will be true if `node` is a leaf node. `level` will be zero if `node` is the root (> 0 otherwise). */
	public function drawNode(node:Node<T>, isLeaf:Bool, level:Int):Void
	{
		drawAABB(node.aabb, node.isLeaf(), level);
	}
	
	/** Draw the whole `tree` (level-wise, starting from the root). */
	public function drawTree(tree:AABBTree<T>):Void
	{
		if (tree.root == null) return;
		
		var height = tree.height;
		var stack = [tree.root];
		while (stack.length > 0) {
			var node = stack.pop();
			if (!node.isLeaf()) {
				stack.push(node.left);
				stack.push(node.right);
			}
			drawNode(node, node.isLeaf(), height - node.invHeight);
		}
	}
}