package ;

import flash.geom.Point;
import haxe.ds.BalancedTree;
import haxe.ds.Option;
import haxe.ds.StringMap;
import RectTools;

using RectTools;

/**
 * ...
 * @author azrafe7
 */
class AABBTree<T>
{

	var enlargeDelta:Float;
	
	var root:AABBTreeNode<T> = null;
	
	var numNodes:Int = 0;
	
	var pool:AABBTreeNodePool<T>;
	
	var maxId:Int = 0;
	var unusedIds:Array<Int>;
	var nodes:Array<AABBTreeNode<T>>;
	
	public function new(enlargeDelta:Float = .5, initialPoolCapacity:Int = 16) 
	{
		this.enlargeDelta = enlargeDelta;
		pool = new AABBTreeNodePool<T>(initialPoolCapacity);
		unusedIds = [];
		nodes = [];
	}
	
	public function getNextId():Int 
	{
		var newId = unusedIds.length > 0 ? unusedIds.pop() : maxId++;
		trace(newId);
		return newId;
	}
	
	public function insertLeaf(aabb:RectLike, data:T):Int
	{
		// create new node and fatten its aabb
		var leafNode = pool.get(aabb, data, null, getNextId());
		leafNode.aabb.inflate(enlargeDelta, enlargeDelta);
		leafNode.invHeight = 0;
		nodes[leafNode.id] = leafNode;
		numNodes++;
		
		if (root == null) {
			root = leafNode;
			return leafNode.id;
		}
		
		// find best sibling to insert the leaf
		var leafAABB = leafNode.aabb;
		var combinedAABB = new AABB();
		var left:AABBTreeNode<T>;
		var right:AABBTreeNode<T>;
		var node = root;
		while (!node.isLeaf())
		{
			left = node.left;
			right = node.right;

			var area = node.aabb.getArea();

			combinedAABB.asUnionOf(node.aabb, leafAABB);
			var combinedArea = combinedAABB.getArea();

			// cost of creating a new parent for this node and the new leaf
			var costParent = 2 * combinedArea;

			// minimum cost of pushing the leaf further down the tree
			var costDescend = 2 * (combinedArea - area);

			// cost of descending into left node
			combinedAABB.asUnionOf(leafAABB, left.aabb);
			var costLeft = combinedAABB.getArea() + costDescend;
			if (!left.isLeaf()) {
				costLeft -= left.aabb.getArea();
			}

			// cost of descending into right node
			combinedAABB.asUnionOf(leafAABB, right.aabb);
			var costRight = combinedAABB.getArea() + costDescend;
			if (!right.isLeaf()) {
				costRight -= right.aabb.getArea();
			}

			// ascend/descend according to the minimum cost
			if (costParent < costLeft && costParent < costRight) {
				break;
			}

			// descend
			node = costLeft < costRight ? left : right;
		}

		var sibling = node;
		
		// create a new parent
		var oldParent = sibling.parent;
		var newParent = pool.get(null, null, oldParent, getNextId());
		combinedAABB.asUnionOf(leafAABB, sibling.aabb);
		newParent.aabb = combinedAABB.clone();
		newParent.invHeight = sibling.invHeight + 1;
		nodes[newParent.id] = newParent;
		numNodes++;

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

		//Validate();
		return leafNode.id;
	}
	
	public function removeLeaf(leafId:Int):Void
	{
		var leafNode = nodes[leafId];
		assert(leafNode.isLeaf());
		
		numNodes--;
		
		if (leafNode == root) {
			nodes[leafNode.id] = null;
			unusedIds.push(leafNode.id);
			pool.put(leafNode);
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
		nodes[parent.id] = null;
		unusedIds.push(parent.id);
		pool.put(parent);

		//Validate();
	}
	
	public function queryRange(aabb:RectLike, ?into:Array<T>):Array<T>
	{
		var res = into != null ? into : new Array<T>();
		if (root == null) return res;
		
		var stack = [root];
		var queryAABB = new AABB(aabb);
		var cnt = 0;
		while (stack.length > 0) {
			var node = stack.pop();
			cnt++;
			
			if (queryAABB.overlaps(node.aabb)) {
				if (node.isLeaf()) res.push(node.data);
				else {
					if (node.left != null) stack.push(node.left);
					if (node.right != null) stack.push(node.right);
				}
			}
		}
		trace(cnt);
		return res;
	}
	
	// Perform a left or right rotation if node A is imbalanced.
	// Returns the new root index.
	public function balance(nodeId:Int):Int
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
		if (balanceValue > 1) {
			var F = C.left;
			var G = C.right;

			// swap A and C
			C.left = A;
			C.parent = A.parent;
			A.parent = C;

			// A's old parent should point to C
			if (C.parent != null) {
				if (C.parent.left == A) {
					C.parent.left = C;
				} else {
					assert(C.parent.right == A);
					C.parent.right = C;
				}
			} else {
				root = C;
			}

			// rotate
			if (F.invHeight > G.invHeight) {
				C.right = F;
				A.right = G;
				G.parent = A;
				A.aabb.asUnionOf(B.aabb, G.aabb);
				C.aabb.asUnionOf(A.aabb, F.aabb);

				A.invHeight = 1 + Std.int(Math.max(B.invHeight, G.invHeight));
				C.invHeight = 1 + Std.int(Math.max(A.invHeight, F.invHeight));
			} else {
				C.right = G;
				A.right = F;
				F.parent = A;
				A.aabb.asUnionOf(B.aabb, F.aabb);
				C.aabb.asUnionOf(A.aabb, G.aabb);

				A.invHeight = 1 + Std.int(Math.max(B.invHeight, F.invHeight));
				C.invHeight = 1 + Std.int(Math.max(A.invHeight, G.invHeight));
			}

			return C.id;
		}
		
		// rotate B up
		if (balanceValue < -1) {
			var D = B.left;
			var E = B.right;

			// swap A and B
			B.left = A;
			B.parent = A.parent;
			A.parent = B;

			// A's old parent should point to B
			if (B.parent != null)
			{
				if (B.parent.left == A) {
					B.parent.left = B;
				} else {
					assert(B.parent.right == A);
					B.parent.right = B;
				}
			} else {
				root = B;
			}

			// rotate
			if (D.invHeight > E.invHeight) {
				B.right = D;
				A.left = E;
				E.parent = A;
				A.aabb.asUnionOf(C.aabb, E.aabb);
				B.aabb.asUnionOf(A.aabb, D.aabb);

				A.invHeight = 1 + Std.int(Math.max(C.invHeight, E.invHeight));
				B.invHeight = 1 + Std.int(Math.max(A.invHeight, D.invHeight));
			} else {
				B.right = E;
				A.left = D;
				D.parent = A;
				A.aabb.asUnionOf(C.aabb, D.aabb);
				B.aabb.asUnionOf(A.aabb, E.aabb);

				A.invHeight = 1 + Std.int(Math.max(C.invHeight, D.invHeight));
				B.invHeight = 1 + Std.int(Math.max(A.invHeight, E.invHeight));
			}

			return B.id;
		}

		return A.id;
	}

	static function assert(cond:Bool) {
		if (!cond) throw "ASSERT FAILED!";
	}
}


@:allow(AABBTree)
@:allow(AABBTreeNodePool)
class AABBTreeNode<T> 
{
	var left:AABBTreeNode<T> = null;
	var right:AABBTreeNode<T> = null;
	var parent:AABBTreeNode<T> = null;
	
	// fat AABB
	var aabb:AABB;
	
	// 0 for leafs
	var invHeight:Int = -1;
	
	var data:T;
	
	var id:Int = -1;
	
	function new(aabb:RectLike, data:T, parent:AABBTreeNode<T> = null, id:Int = -1)
	{
		this.aabb = new AABB(aabb);

		this.data = data;
		this.parent = parent;
		this.id = id;
	}
	
	
	inline function isLeaf():Bool
	{
		return left == null;
	}
}


@:publicFields
class AABB
{
	var minX:Float;
	var maxX:Float;
	var minY:Float;
	var maxY:Float;

	function new(?rect:RectLike):Void 
	{
		if (rect != null) {
			minX = rect.x;
			minY = rect.y;
			maxX = rect.x + rect.width;
			maxY = rect.y + rect.height;
		} else {
			minX = minY = maxX = maxY = 0;
		}
	}

	function inflate(deltaX:Float, deltaY:Float):AABB
	{
		minX -= deltaX;
		minY -= deltaY;
		maxX += deltaX;
		maxY += deltaY;
		return this;
	}
	
	function getPerimeter():Float
	{
		return 2 * ((maxX - minX) + (maxY - minY));
	}
	
	function getArea():Float
	{
		return (maxX - minX) * (maxY - minY);
	}
	
	function getCenter():PointLike
	{
		return { x:minX + .5 * (maxX - minX), y:minY + .5 * (maxY - minY) };
	}
	
	function union(aabb:AABB):AABB
	{
		minX = Math.min(minX, aabb.minX);
		minY = Math.min(minY, aabb.minY);
		maxX = Math.max(maxX, aabb.maxX);
		maxY = Math.max(maxY, aabb.maxY);
		return this;
	}
	
	function asUnionOf(aabb1:AABB, aabb2:AABB):AABB
	{
		minX = Math.min(aabb1.minX, aabb2.minX);
		minY = Math.min(aabb1.minY, aabb2.minY);
		maxX = Math.max(aabb1.maxX, aabb2.maxX);
		maxY = Math.max(aabb1.maxY, aabb2.maxY);
		return this;
	}
	
	function clone():AABB
	{
		return new AABB( { x:minX, y:minY, width:maxX - minX, height:maxY - minY } );
	}

	function fromAABB(aabb:AABB):AABB
	{
		minX = aabb.minX;
		minY = aabb.minY;
		maxX = aabb.maxX;
		maxY = aabb.maxY;
		return this;
	}

	function fromRect(aabb:RectLike):AABB
	{
		minX = aabb.x;
		minY = aabb.y;
		maxX = aabb.x + aabb.width;
		maxY = aabb.y + aabb.height;
		return this;
	}
	
	function overlaps(aabb:AABB):Bool
	{
		return !(minX > aabb.maxX || maxX < aabb.minX || minY > aabb.maxY || maxY < aabb.minY);
	}
}

@:allow(AABBTree)
class AABBTreeNodePool<T>
{
	var INCREASE_FACTOR:Float = 1.5;
	var ZERO_RECT:RectLike = RectTools.getNewRect();
	
	var capacity:Int;
	
	var freeNodes:Array<AABBTreeNode<T>>;
	
	function new(capacity:Int)
	{
		this.capacity = capacity;
		freeNodes = new Array<AABBTreeNode<T>>();
		for (i in 0...capacity) freeNodes.push(new AABBTreeNode(ZERO_RECT, null));
	}
	
	function get(aabb:RectLike, data:T, parent:AABBTreeNode<T> = null, id:Int = -1):AABBTreeNode<T>
	{
		var newNode:AABBTreeNode<T>;
		
		if (freeNodes.length > 0) {
			newNode = freeNodes.pop();
			if (aabb != null) newNode.aabb.fromRect(aabb);
			newNode.data = data;
			newNode.parent = parent;
			newNode.id = id;
		} else {
			newNode = new AABBTreeNode(aabb, data, parent, id);
			capacity = Std.int(capacity * INCREASE_FACTOR);
			for (i in 0...capacity) freeNodes.push(new AABBTreeNode(ZERO_RECT, null));
		}
		
		return newNode;
	}
	
	function put(node:AABBTreeNode<T>):Void 
	{
		freeNodes.push(node);
		node.parent = node.left = node.right = null;
		node.id = -1;
		node.invHeight = -1;
		node.data = null;
	}
}