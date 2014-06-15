/*
 * This file is part of the AABBTree library for haxe (https://github.com/azrafe7/AABBTree).
 * 
 * Developed by Giuseppe Di Mauro (aka azrafe7) and realeased under the MIT license (see LICENSE file).
 * 
 * The code is heavily inspired by the implementations of a dynamic AABB tree by 
 * 
 *  - Nathanael Presson 	(Bullet Physics - http://bulletphysics.org)
 *	- Erin Catto 			(Box2D - http://www.box2d.org)
 */

package ds.aabbtree;

/**
 * Node pool used by AABBTree.
 * 
 * @author azrafe7
 */
@:publicFields
class NodePool<T>
{
	/** The pool will grow by this factor when it's empty. */
	var growthFactor:Float;
	
	/** Initial capacity of the pool. */
	var capacity:Int;
	
	var freeNodes:Array<Node<T>>;
	
	
	function new(capacity:Int, growthFactor:Float = 2)
	{
		this.capacity = capacity;
		this.growthFactor = growthFactor;
		freeNodes = new Array<Node<T>>();
		for (i in 0...capacity) freeNodes.push(new Node(new AABB(), null));
	}
	
	/** Fetches a node from the pool (if available) or creates a new one. */
	function get(x:Float, y:Float, width:Float = 0, height:Float = 0, ?data:T, parent:Node<T> = null, id:Int = -1):Node<T>
	{
		var newNode:Node<T>;
		
		if (freeNodes.length > 0) {
			newNode = freeNodes.pop();
			newNode.aabb.setTo(x, y, width, height);
			newNode.data = data;
			newNode.parent = parent;
			newNode.id = id;
		} else {
			newNode = new Node(new AABB(x, y, width, height), data, parent, id);
			capacity = Std.int(capacity * growthFactor);
			grow(capacity);
		}
		
		return newNode;
	}
	
	/** Reinserts an unused node into the pool (for future use). */
	function put(node:Node<T>):Void 
	{
		freeNodes.push(node);
		node.parent = node.left = node.right = null;
		node.id = -1;
		node.invHeight = -1;
		node.data = null;
	}
	
	/** Resets the pool to its capacity (removing all the other nodes). */
	function reset():Void 
	{
		if (freeNodes.length > capacity) freeNodes.splice(capacity, freeNodes.length - capacity);
	}
	
	/** Grows the pool to contain `n` nodes. Nothing will be done if `n` is less than the current number of nodes. */
	function grow(n:Int):Void
	{
		var len = freeNodes.length;
		if (n <= len) return;
		
		for (i in len...n) {
			freeNodes.push(new Node(new AABB(), null));
		}
	}
}