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
 * Node class used by AABBTree.
 * 
 * @author azrafe7
 */
@:publicFields
class Node<T> 
{
	var left:Node<T> = null;
	var right:Node<T> = null;
	var parent:Node<T> = null;
	
	// fat AABB
	var aabb:AABB;
	
	// 0 for leafs
	var invHeight:Int = -1;
	
	var data:T;
	
	var id:Int = -1;
	
	function new(aabb:AABB, data:T, parent:Node<T> = null, id:Int = -1)
	{
		this.aabb = aabb;
		this.data = data;
		this.parent = parent;
		this.id = id;
	}
	
	/** If it's a leaf both left and right nodes should be null. */
	inline function isLeaf():Bool
	{
		return left == null;
	}
}
