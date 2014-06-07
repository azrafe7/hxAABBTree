package ;

import AABB;

/**
 * ...
 * @author azrafe7
 */
class AABBTree<T>
{
	/** How much to fatten the aabb. */
	var fattenDelta:Float;
	
	/** Total number of nodes. */
	var numNodes:Int = 0;
	
	/* Pooled nodes stuff. */
	var pool:AABBTreeNodePool<T>;
	var maxId:Int = 0;
	var unusedIds:Array<Int>;
	
	var root:AABBTreeNode<T> = null;
	
	/** Cache-friendly array of nodes. */
	var nodes:Array<AABBTreeNode<T>>;

	
	/**
	 * Creates a new AABBTree.
	 * 
	 * @param	enlargeDelta			How much to fatten the aabb's (to avoid updating them to frequently when the underlying data moves).
	 * @param	initialPoolCapacity		How much free nodes to have in the pool initially.
	 */
	public function new(fattenDelta:Float = .5, initialPoolCapacity:Int = 16):Void
	{
		this.fattenDelta = fattenDelta;
		pool = new AABBTreeNodePool<T>(initialPoolCapacity);
		unusedIds = [];
		nodes = [];
	}
	
	
	/** Gets the next available id for a node, fecthing it from the list of unused ones if available. */
	public function getNextId():Int 
	{
		var newId = unusedIds.length > 0 ? unusedIds.pop() : maxId++;
		trace(newId);
		return newId;
	}
	
	/** 
	 * Inserts a leaf object with the specified `aabb` and associated `data`.
	 * 
	 * @return The index of the inserted node.
	 */
	public function insertLeaf(aabb:RectLike, data:T):Int
	{
		// create new node and fatten its aabb
		var leafNode = pool.get(aabb, data, null, getNextId());
		leafNode.aabb.inflate(fattenDelta, fattenDelta);
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
	
	/** 
	 * Removes the leaf node with the specified `leafId` from the tree (must be a leaf node).
	 */
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
	
	/**
	 * Performs a left or right rotation if `nodeId` is unbalanced.
	 * 
	 * Returns the new root index.
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

	//            A			parent
	//          /   \
	//         B     C		left and right nodes
	//        / \   / \
	//       D   E F   G
	private function rotateLeft(parentNode:AABBTreeNode<T>, leftNode:AABBTreeNode<T>, rightNode:AABBTreeNode<T>):Int
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
	
	//            A			parent
	//          /   \
	//         B     C		left and right nodes
	//        / \   / \
	//       D   E F   G
	private function rotateRight(parentNode:AABBTreeNode<T>, leftNode:AABBTreeNode<T>, rightNode:AABBTreeNode<T>):Int
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



@:allow(AABBTree)
class AABBTreeNodePool<T>
{
	/** The pool will grow by `capacity * INCREASE_FACTOR` factor when it's empty. */
	var INCREASE_FACTOR:Float = 1.5;
	
	static var ZERO_RECT:RectLike = { x:0, y:0, width:0, height:0 };
	
	/** Initial capacity of the pool. */
	var capacity:Int;
	
	var freeNodes:Array<AABBTreeNode<T>>;
	
	
	function new(capacity:Int)
	{
		this.capacity = capacity;
		freeNodes = new Array<AABBTreeNode<T>>();
		for (i in 0...capacity) freeNodes.push(new AABBTreeNode(ZERO_RECT, null));
	}
	
	/** Fetches a node from the pool (if available) or creates a new one. */
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
	
	/** Reinserts an unused node into the pool (for future use). */
	function put(node:AABBTreeNode<T>):Void 
	{
		freeNodes.push(node);
		node.parent = node.left = node.right = null;
		node.id = -1;
		node.invHeight = -1;
		node.data = null;
	}
}