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

package ds;

import ds.AABB;
import ds.aabbtree.DebugRenderer;
import ds.aabbtree.Node;
import ds.aabbtree.NodePool;
import ds.aabbtree.IInsertStrategy;
import ds.aabbtree.InsertStrategyArea;


/**
 * Values that can be returned from query and raycast callbacks to decide how to proceed.
 */
enum HitBehaviour {
	SKIP;				// continue but don't include in results
	INCLUDE;			// include and continue (default)
	INCLUDE_AND_STOP;	// include and break out of the search
	STOP;				// break out of the search
}

/**
 * AABBTree implementation. A spatial partitioning data structure.
 * 
 * @author azrafe7
 */
@:allow(ds.aabbtree.DebugRenderer)
class AABBTree<T>
{
	/** How much to fatten the aabb. */
	public var fattenDelta:Float;
	
	/** Algorithm to use for choosing where to insert a new leaf. */
	public var insertStrategy:IInsertStrategy<T>;
	
	/** Total number of nodes. */
	public var numNodes(get, null):Int = 0;
	inline private function get_numNodes():Int {
		return nodes.length;
	}
	
	/** Total number of leaves. */
	public var numLeaves(get, null):Int = 0;
	inline private function get_numLeaves():Int {
		return [for (id in leaves.keys()) id].length;
	}
	
	/** Height of the tree. */
	public var height(get, null):Int;
	inline private function get_height():Int
	{
		return root != null ? root.invHeight : -1;
	}
	
	
	/* Pooled nodes stuff. */
	var pool:NodePool<T>;
	var maxId:Int = 0;
	var unusedIds:Array<Int>;
	
	var root:Node<T> = null;
	
	/* Cache-friendly array of nodes. Entries are set to null when removed (to be reused later). */
	var nodes:Array<Node<T>>;
	
	/* Set of leaf nodes indices (implement as IntMap - values are the same as keys). */
	var leaves:Map<Int, Int>;

	
	/**
	 * Creates a new AABBTree.
	 * 
	 * @param	fattenDelta				How much to fatten the aabbs (to avoid updating the nodes too frequently when the underlying data moves/resizes).
	 * @param	insertStrategy			Strategy to use for choosing where to insert a new leaf. Defaults to `InsertStrategyArea`.
	 * @param	initialPoolCapacity		How much free nodes to have in the pool initially.
	 */
	public function new(fattenDelta:Float = 10, ?insertStrategy:IInsertStrategy<T>, initialPoolCapacity:Int = 16):Void
	{
		this.fattenDelta = fattenDelta;
		this.insertStrategy = insertStrategy != null ? insertStrategy : new InsertStrategyArea<T>();
		pool = new NodePool<T>(initialPoolCapacity);
		unusedIds = [];
		nodes = [];
		leaves = new Map<Int, Int>();
	}
	
	/** 
	 * Inserts a leaf node with the specified `aabb` values and associated `data`.
	 * 
	 * The user must store the returned id and use it later to apply changes to the node (removeLeaf(), updateLeaf()).
	 * 
	 * @return The index of the inserted node.
	 */
	public function insertLeaf(x:Float, y:Float, width:Float = 0, height:Float = 0, ?data:T):Int
	{
		// create new node and fatten its aabb
		var leafNode = pool.get(x, y, width, height, data, null, getNextId());
		leafNode.aabb.inflate(fattenDelta, fattenDelta);
		leafNode.invHeight = 0;
		nodes[leafNode.id] = leafNode;
		leaves[leafNode.id] = leafNode.id;
		
		if (root == null) {
			root = leafNode;
			return leafNode.id;
		}
		
		// find best sibling to insert the leaf
		var leafAABB = leafNode.aabb;
		var combinedAABB = new AABB();
		var left:Node<T>;
		var right:Node<T>;
		var node = root;
		while (!node.isLeaf())
		{
			switch (insertStrategy.choose(leafAABB, node))
			{
				case InsertChoice.PARENT:
					break;
				case InsertChoice.DESCEND_LEFT:
					node = node.left;
				case InsertChoice.DESCEND_RIGHT:
					node = node.right;
			}
		}

		var sibling = node;
		
		// create a new parent
		var oldParent = sibling.parent;
		combinedAABB.asUnionOf(leafAABB, sibling.aabb);
		var newParent = pool.get(combinedAABB.x, combinedAABB.y, combinedAABB.width, combinedAABB.height, null, oldParent, getNextId());
		newParent.invHeight = sibling.invHeight + 1;
		nodes[newParent.id] = newParent;

		// the sibling was not the root
		if (oldParent != null) {
			
			if (oldParent.left == sibling) {
				oldParent.left = newParent;
			} else {
				oldParent.right = newParent;
			}
		} else {
			
			// the sibling was the root
			root = newParent;
		}
		newParent.left = sibling;
		newParent.right = leafNode;
		sibling.parent = newParent;
		leafNode.parent = newParent;

		// walk back up the tree fixing heights and AABBs
		node = leafNode.parent;
		while (node != null)
		{
			node = nodes[balance(node.id)];

			left = node.left;
			right = node.right;

			assert(left != null);
			assert(right != null);

			node.invHeight = 1 + Std.int(Math.max(left.invHeight, right.invHeight));
			node.aabb.asUnionOf(left.aabb, right.aabb);

			node = node.parent;
		}

		validate();
		return leafNode.id;
	}
	
	/** 
	 * Updates the aabb of leaf node with the specified `leafId` (must be a leaf node).
	 * 
	 * @return False if the fat aabb didn't need to be expanded.
	 */
	public function updateLeaf(leafId:Int, x:Float, y:Float, width:Float = 0, height:Float = 0):Bool
	{
		var leafNode = nodes[leafId];
		assert(leafNode.isLeaf());
		
		var newAABB = new AABB(x, y, width, height);
		var leafNode = nodes[leafId];
		
		if (leafNode.aabb.contains(newAABB)) {
			return false;
		}
		
		var data = leafNode.data;
		removeLeaf(leafId);
		var newId = insertLeaf(x, y, width, height, data);
		
		assert(newId == leafId);
		
		return true;
	}
	
	/** 
	 * Removes the leaf node with the specified `leafId` from the tree (must be a leaf node).
	 */
	public function removeLeaf(leafId:Int):Void
	{
		var leafNode = nodes[leafId];
		assert(leafNode.isLeaf());
		
		leaves.remove(leafId);
		
		if (leafNode == root) {
			disposeNode(leafId);
			root = null;
			return;
		}

		var parent = leafNode.parent;
		var grandParent = parent.parent;
		var sibling = parent.left == leafNode ? parent.right : parent.left;

		if (grandParent != null) {
			// connect sibling to grandParent
			if (grandParent.left == parent) {
				grandParent.left = sibling;
			} else {
				grandParent.right = sibling;
			}
			sibling.parent = grandParent;

			// adjust ancestor bounds
			var node = grandParent;
			while (node != null)
			{
				node = nodes[balance(node.id)];

				var left = node.left;
				var right = node.right;

				node.aabb.asUnionOf(left.aabb, right.aabb);
				node.invHeight = 1 + Std.int(Math.max(left.invHeight, right.invHeight));

				node = node.parent;
			}
		} else {
			root = sibling;
			root.parent = null;
		}
		
		// destroy parent
		assert(parent.id != -1);
		disposeNode(parent.id);
		disposeNode(leafId);
		
		validate();
	}
	
	/** 
	 * Removes all nodes from the tree. 
	 * 
	 * @param	resetPool	If true the internal pool will be reset to its initial capacity.
	 */
	public function clear(resetPool:Bool = false)
	{
		var count = numNodes;
		while (count > 0) {
			var node = nodes[count - 1];
			disposeNode(node.id);
			count--;
		}
		root = null;
		leaves = new Map<Int, Int>();
		maxId = 0;
		if (resetPool) pool.reset();
		
		assert(numNodes == 0);
	}
	
	/** Rebuild the tree using a bottom-up strategy (should result in a better tree, but is expensive). */
	public function rebuild():Void 
	{
		if (root == null) return;

		// free non-leaf nodes
		for (node in nodes) {
			if (!node.isLeaf()) {
				disposeNode(node.id);
			} else {
				node.parent = null;
			}
		}
		
		// copy leaves ids
		var leafIds = [for (id in leaves.keys()) id];
		
		var aabb = new AABB();
		var count = leafIds.length;
		while (count > 1) {
			var minCost = Math.POSITIVE_INFINITY;
			var iMin = -1;
			var jMin = -1;
			
			// find pair with least perimeter enlargement
			for (i in 0...count) {
				var iAABB = nodes[leafIds[i]].aabb;

				for (j in i + 1...count) {
					var jAABB = nodes[leafIds[j]].aabb;
					
					aabb.asUnionOf(iAABB, jAABB);
					var cost = aabb.getPerimeter();
					if (cost < minCost) {
						iMin = i;
						jMin = j;
						minCost = cost;
					}
				}
			}

			var left = nodes[leafIds[iMin]];
			var right = nodes[leafIds[jMin]];
			aabb.asUnionOf(left.aabb, right.aabb);
			var parent = pool.get(aabb.x, aabb.y, aabb.width, aabb.height, null, null, getNextId());
			parent.left = left;
			parent.right = right;
			parent.invHeight = Std.int(1 + Math.max(left.invHeight, right.invHeight));
			nodes[parent.id] = parent;
			
			left.parent = parent;
			right.parent = parent;
			
			leafIds[iMin] = parent.id;
			leafIds[jMin] = leafIds[count - 1];
			
			count--;
		}

		root = nodes[leafIds[0]];

		validate();
	}
	
	/** Returns a list of all the data objects attached to leaves (optionally appending them to `into`). */
	public function getLeavesData(?into:Array<T>):Array<T>
	{
		var res = into != null ? into : [];
		for (id in leaves.keys()) res.push(nodes[id].data);
		return res;
	}
	
	/** Returns a list of all the leaves' ids (optionally appending them to `into`). */
	public function getLeavesIds(?into:Array<Int>):Array<Int>
	{
		var res = into != null ? into : [];
		for (id in leaves.keys()) res.push(id);
		return res;
	}
	
	/** Returns data associated to the node with the specified `leafId` (must be a leaf node). */
	public function getData(leafId:Int):T
	{
		var leafNode = nodes[leafId];
		assert(leafNode.isLeaf());
		
		return leafNode.data;
	}
	
	/**
	 * Queries the tree for objects in the specified AABB.
	 * 
	 * @param	into			Hit objects will be appended to this (based on callback return value).
	 * @param	strictMode		If set to true only objects fully contained in the AABB will be processed. Otherwise they will be checked for intersection (default).
	 * @param	callback		A function called for every object hit (function callback(data:T, id:Int):HitBehaviour).
	 * 
	 * @return A list of all the objects found (or `into` if it was specified).
	 */
	public function query(x:Float, y:Float, width:Float = 0, height:Float = 0, strictMode:Bool = false, ?into:Array<T>, ?callback:T->Int->HitBehaviour):Array<T>
	{
		var res = into != null ? into : new Array<T>();
		if (root == null) return res;
		
		var stack = [root];
		var queryAABB = new AABB(x, y, width, height);
		var cnt = 0;
		while (stack.length > 0) {
			var node = stack.pop();
			cnt++;
			
			if (queryAABB.overlaps(node.aabb)) {
				if (node.isLeaf() && (!strictMode || (strictMode && queryAABB.contains(node.aabb)))) {
					if (callback != null) {
						var hitBehaviour = callback(node.data, node.id);
						if (hitBehaviour == INCLUDE || hitBehaviour == INCLUDE_AND_STOP) {
							res.push(node.data);
						}
						if (hitBehaviour == STOP || hitBehaviour == INCLUDE_AND_STOP) {
							break;
						}
					} else {
						res.push(node.data);
					}
				} else {
					if (node.left != null) stack.push(node.left);
					if (node.right != null) stack.push(node.right);
				}
			}
		}
		//trace("examined: " + cnt);
		return res;
	}
	
	/**
	 * Queries the tree for objects crossing the specified ray.
	 * 
	 * Notes: 
	 * 	- the intersecting objects will be returned in no particular order (closest ones to the start point may appear later in the list!).
	 *  - the callback will also be called if an object fully contains the ray's start and end point.
	 * 
	 * TODO: see how this can be optimized and return results in order
	 * 
	 * @param	into		Hit objects will be appended to this (based on callback return value).
	 * @param	callback	A function called for every object hit (function callback(data:T, id:Int):HitBehaviour).
	 * 
	 * @return A list of all the objects found (or `into` if it was specified).
	 */
	public function rayCast(fromX:Float, fromY:Float, toX:Float, toY:Float, ?into:Array<T>, ?callback:T->Int->HitBehaviour):Array<T>
	{
		var res = into != null ? into : new Array<T>();
		if (root == null) return res;
		
		var queryAABBResultsIds = [];

		
		function rayAABBCallback(data:T, id:Int):HitBehaviour
		{
			var node = nodes[id];
			var aabb = node.aabb;
			var fromPointAABB = new AABB(fromX, fromY);
			var toPointAABB = new AABB(toX, toY);
			
			var hit = false;
			for (i in 0...4) {	// test for intersection with node's aabb edges
				switch (i) {
					case 0:	// top edge
						hit = segmentIntersect(fromX, fromY, toX, toY, aabb.minX, aabb.minY, aabb.maxX, aabb.minY);
					case 1:	// left edge
						hit = segmentIntersect(fromX, fromY, toX, toY, aabb.minX, aabb.minY, aabb.minX, aabb.maxY);
					case 2:	// bottom edge
						hit = segmentIntersect(fromX, fromY, toX, toY, aabb.minX, aabb.maxY, aabb.maxX, aabb.maxY);
					case 3:	// right edge
						hit = segmentIntersect(fromX, fromY, toX, toY, aabb.maxX, aabb.minY, aabb.maxX, aabb.maxY);
					default:	
				}
				if (hit) break;
			}
			
			// add intersected node id to array
			if (hit || (!hit && aabb.contains(fromPointAABB))) {
				queryAABBResultsIds.push(id);
			}
			
			return SKIP;	// don't bother adding to results
		}
		
		var tmp:Float;
		var rayAABB = new AABB(fromX, fromY, toX - fromX, toY - fromY);
		if (rayAABB.minX > rayAABB.maxX) {
			tmp = rayAABB.maxX;
			rayAABB.maxX = rayAABB.minX;
			rayAABB.minX = tmp;
		}
		if (rayAABB.minY > rayAABB.maxY) {
			tmp = rayAABB.maxY;
			rayAABB.maxY = rayAABB.minY;
			rayAABB.minY = tmp;
		}
		
		query(rayAABB.x, rayAABB.y, rayAABB.width , rayAABB.height, false, null, rayAABBCallback);
		
		for (id in queryAABBResultsIds) {
			var node = nodes[id];
			if (callback != null) {
				var hitBehaviour = callback(node.data, node.id);
				if (hitBehaviour == INCLUDE || hitBehaviour == INCLUDE_AND_STOP) {
					res.push(node.data);
				}
				if (hitBehaviour == STOP || hitBehaviour == INCLUDE_AND_STOP) {
					break;
				}
			} else {
				res.push(node.data);
			}
		}
		
		return res;
	}
	
	/** Gets the next available id for a node, fecthing it from the list of unused ones if available. */
	private function getNextId():Int 
	{
		var newId = unusedIds.length > 0 && unusedIds[unusedIds.length - 1] < maxId ? unusedIds.pop() : maxId++;
		return newId;
	}
	
	/** Returns the node with the specified `id` to the pool. */
	private function disposeNode(id:Int) {
		assert(nodes[id] != null);

		var node = nodes[id];
		nodes[node.id] = null;
		unusedIds.push(node.id);
		pool.put(node);
	}
	
	/**
	 * Performs a left or right rotation if `nodeId` is unbalanced.
	 * 
	 * @return The new parent index.
	 */
	private function balance(nodeId:Int):Int
	{
		var A = nodes[nodeId];
		assert(A != null);

		if (A.isLeaf() || A.invHeight < 2) {
			return A.id;
		}

		var B = A.left;
		var C = A.right;

		var balanceValue = C.invHeight - B.invHeight;

		// rotate C up
		if (balanceValue > 1) return rotateLeft(A, B, C);
		
		// rotate B up
		if (balanceValue < -1) return rotateRight(A, B, C);

		return A.id;
	}

	/** Returns max height distance between two children (of the same parent) in the tree. */
	public function getMaxBalance():Int
	{
		var maxBalance = 0;
		for (i in 0...nodes.length) {
			var node = nodes[i];
			if (node.invHeight <= 1 || node == null) continue;

			assert(!node.isLeaf());

			var left = node.left;
			var right = node.right;
			var balance = Math.abs(right.invHeight - left.invHeight);
			maxBalance = Std.int(Math.max(maxBalance, balance));
		}

		return maxBalance;
	}
	
	/*
	 *           A			parent
	 *         /   \
	 *        B     C		left and right nodes
	 *             / \
	 *            F   G
	 */
	private function rotateLeft(parentNode:Node<T>, leftNode:Node<T>, rightNode:Node<T>):Int
	{
		var F = rightNode.left;
		var G = rightNode.right;

		// swap A and C
		rightNode.left = parentNode;
		rightNode.parent = parentNode.parent;
		parentNode.parent = rightNode;

		// A's old parent should point to C
		if (rightNode.parent != null) {
			if (rightNode.parent.left == parentNode) {
				rightNode.parent.left = rightNode;
			} else {
				assert(rightNode.parent.right == parentNode);
				rightNode.parent.right = rightNode;
			}
		} else {
			root = rightNode;
		}

		// rotate
		if (F.invHeight > G.invHeight) {
			rightNode.right = F;
			parentNode.right = G;
			G.parent = parentNode;
			parentNode.aabb.asUnionOf(leftNode.aabb, G.aabb);
			rightNode.aabb.asUnionOf(parentNode.aabb, F.aabb);

			parentNode.invHeight = 1 + Std.int(Math.max(leftNode.invHeight, G.invHeight));
			rightNode.invHeight = 1 + Std.int(Math.max(parentNode.invHeight, F.invHeight));
		} else {
			rightNode.right = G;
			parentNode.right = F;
			F.parent = parentNode;
			parentNode.aabb.asUnionOf(leftNode.aabb, F.aabb);
			rightNode.aabb.asUnionOf(parentNode.aabb, G.aabb);

			parentNode.invHeight = 1 + Std.int(Math.max(leftNode.invHeight, F.invHeight));
			rightNode.invHeight = 1 + Std.int(Math.max(parentNode.invHeight, G.invHeight));
		}
		
		return rightNode.id;
	}
	
	/*
	 *           A			parent
	 *         /   \
	 *        B     C		left and right nodes
	 *       / \
	 *      D   E
	 */
	private function rotateRight(parentNode:Node<T>, leftNode:Node<T>, rightNode:Node<T>):Int
	{
		var D = leftNode.left;
		var E = leftNode.right;

		// swap A and B
		leftNode.left = parentNode;
		leftNode.parent = parentNode.parent;
		parentNode.parent = leftNode;

		// A's old parent should point to B
		if (leftNode.parent != null)
		{
			if (leftNode.parent.left == parentNode) {
				leftNode.parent.left = leftNode;
			} else {
				assert(leftNode.parent.right == parentNode);
				leftNode.parent.right = leftNode;
			}
		} else {
			root = leftNode;
		}

		// rotate
		if (D.invHeight > E.invHeight) {
			leftNode.right = D;
			parentNode.left = E;
			E.parent = parentNode;
			parentNode.aabb.asUnionOf(rightNode.aabb, E.aabb);
			leftNode.aabb.asUnionOf(parentNode.aabb, D.aabb);

			parentNode.invHeight = 1 + Std.int(Math.max(rightNode.invHeight, E.invHeight));
			leftNode.invHeight = 1 + Std.int(Math.max(parentNode.invHeight, D.invHeight));
		} else {
			leftNode.right = E;
			parentNode.left = D;
			D.parent = parentNode;
			parentNode.aabb.asUnionOf(rightNode.aabb, D.aabb);
			leftNode.aabb.asUnionOf(parentNode.aabb, E.aabb);

			parentNode.invHeight = 1 + Std.int(Math.max(rightNode.invHeight, D.invHeight));
			leftNode.invHeight = 1 + Std.int(Math.max(parentNode.invHeight, E.invHeight));
		}

		return leftNode.id;
	}
	
	private function getNode(id:Int):Node<T> 
	{
		assert(id >= 0 && nodes[id] != null);
		return nodes[id];
	}
	
	/** Tests validity of node (and its children). */
	private function validateNode(id:Int):Void 
	{
		var node = nodes[id];
		assert(node != null);
		
		var left = node.left;
		var right = node.right;
		
		if (node.isLeaf()) {
			assert(left == null);
			assert(right == null);
			node.invHeight = 0;
			assert(leaves[node.id] >= 0);
		}
		
		assert(left.id >= 0);
		assert(right.id >= 0);
		
		assert(node.invHeight == 1 + Math.max(left.invHeight, right.invHeight));
		var aabb = new AABB();
		aabb.asUnionOf(left.aabb, right.aabb);
		assert(node.aabb.minX == aabb.minX);
		assert(node.aabb.minY == aabb.minY);
		assert(node.aabb.maxX == aabb.maxX);
		assert(node.aabb.maxY == aabb.maxY);
		
		validateNode(left.id);
		validateNode(right.id);
	}
	
	static private function segmentIntersect(p0x:Float, p0y:Float, p1x:Float, p1y:Float, q0x:Float, q0y:Float, q1x:Float, q1y:Float):Bool
	{
		var intX:Float, intY:Float;
		var a1:Float, a2:Float;
		var b1:Float, b2:Float;
		var c1:Float, c2:Float;
	 
		a1 = p1y - p0y;
		b1 = p0x - p1x;
		c1 = p1x * p0y - p0x * p1y;
		a2 = q1y - q0y;
		b2 = q0x - q1x;
		c2 = q1x * q0y - q0x * q1y;
	 
		var denom:Float = a1 * b2 - a2 * b1;
		if (denom == 0){
			return false;
		}
		
		intX = (b1 * c2 - b2 * c1) / denom;
		intY = (a2 * c1 - a1 * c2) / denom;
	 
		// check to see if distance between intersection and endpoints
		// is longer than actual segments.
		// return false otherwise.
		if (distanceSquared(intX, intY, p1x, p1y) > distanceSquared(p0x, p0y, p1x, p1y)) return false;
		if (distanceSquared(intX, intY, p0x, p0y) > distanceSquared(p0x, p0y, p1x, p1y)) return false;
		if (distanceSquared(intX, intY, q1x, q1y) > distanceSquared(q0x, q0y, q1x, q1y)) return false;
		if (distanceSquared(intX, intY, q0x, q0y) > distanceSquared(q0x, q0y, q1x, q1y)) return false;
		
		return true;
	}
	
	inline static private function distanceSquared(px:Float, py:Float, qx:Float, qy:Float):Float { return sqr(px - qx) + sqr(py - qy); }
	
	inline static private function sqr(x:Float):Float { return x * x; }
	
	inline static function validate() {
	#if DEBUG
		if (root != null) validateNode(root.id);
	#end
	}
	
	inline static function assert(cond:Bool) {
	#if DEBUG
		if (!cond) throw "ASSERT FAILED!";
	#end
	}
}