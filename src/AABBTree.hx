package ;

import AABB;
import IInsertStrategy;


/**
 * AABBTree implementation. A spatial partitioning data structure.
 * 
 * @author azrafe7
 */
class AABBTree<T>
{
	/** How much to fatten the aabb. */
	public var fattenDelta:Float;
	
	/** Algorithm to use for choosing where to insert a new leaf. */
	public var insertStrategy:IInsertStrategy<T>;
	
	/** Total number of nodes. */
	public var numNodes(default, null):Int = 0;
	
	/** Total number of leaves. */
	public var numLeaves(default, null):Int = 0;
	
	/** Height of the tree. */
	public var height(get, null):Int;
	inline private function get_height():Int
	{
		return root != null ? root.invHeight : -1;
	}
	
	
	/* Pooled nodes stuff. */
	var pool:AABBTreeNodePool<T>;
	var maxId:Int = 0;
	var unusedIds:Array<Int>;
	
	var root:AABBTreeNode<T> = null;
	
	/* Cache-friendly array of nodes. Entries are set to null when removed (to be reused later). */
	var nodes:Array<AABBTreeNode<T>>;
	
	/* Indices of leaf nodes for fast access. */
	var leaves:Array<Int>;

	
	/**
	 * Creates a new AABBTree.
	 * 
	 * @param	fattenDelta				How much to fatten the aabb's (to avoid updating them to frequently when the underlying data moves/resizes).
	 * @param	insertStrategy			Algorithm to use for choosing where to insert a new leaf. Defaults to `InsertStrategyArea`.
	 * @param	initialPoolCapacity		How much free nodes to have in the pool initially.
	 */
	public function new(fattenDelta:Float = 10, ?insertStrategy:IInsertStrategy<T>, initialPoolCapacity:Int = 16):Void
	{
		this.fattenDelta = fattenDelta;
		this.insertStrategy = insertStrategy != null ? insertStrategy : new InsertStrategyArea<T>();
		pool = new AABBTreeNodePool<T>(initialPoolCapacity);
		unusedIds = [];
		nodes = [];
		leaves = [];
	}
	
	/** 
	 * Inserts a leaf node with the specified `aabb` values and associated `data`.
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
		numNodes++;
		numLeaves++;
		leaves.push(leafNode.id);
		
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
			switch (insertStrategy.choose(leafAABB, node))
			{
				case InsertBehaviour.PARENT:
					break;
				case InsertBehaviour.DESCEND_LEFT:
					node = node.left;
				case InsertBehaviour.DESCEND_RIGHT:
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
		insertLeaf(x, y, width, height, data);
		return true;
	}
	
	/** 
	 * Removes the leaf node with the specified `leafId` from the tree (must be a leaf node).
	 */
	public function removeLeaf(leafId:Int):Void
	{
		var leafNode = nodes[leafId];
		assert(leafNode.isLeaf());
		
		numNodes--;
		numLeaves--;
		if (numLeaves > 0) leaves[leaves.indexOf(leafId)] = leaves[numLeaves];
		else leaves.pop();
		
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
		
		validate();
	}
	
	/** Removes all nodes from the tree. */
	public function clear(resetPool:Bool = false)
	{
		while (numNodes > 0) {
			var node = nodes[numNodes - 1];
			disposeNode(node.id);
			numNodes--;
		}
		root = null;
		numLeaves = 0;
		leaves = [];
		maxId = 0;
		unusedIds = [];
		if (resetPool) pool.reset();
	}
	
	/** Rebuild the tree using an optimal (but expensive) strategy. */
	public function rebuild():Void 
	{
		if (root == null) return;
		
		// free non-leaf nodes
		for (node in nodes) {
			if (!node.isLeaf()) {
				
			}
		}
		
	}
	
	/** Returns a list of all the data objects attached to leaves (optionally appending them to `into`). */
	public function getLeavesData(?into:Array<T>):Array<T>
	{
		var res = into != null ? into : [];
		for (id in leaves) res.push(nodes[id].data);
		return res;
	}
	
	/** Returns a list of all the leaves' ids (optionally appending them to `into`). */
	public function getLeavesIds(?into:Array<Int>):Array<Int>
	{
		var res = into != null ? into : [];
		for (id in leaves) res.push(id);
		return res;
	}
	
	public function query(x:Float, y:Float, width:Float = 0, height:Float = 0, ?into:Array<T>):Array<T>
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
				if (node.isLeaf()) res.push(node.data);
				else {
					if (node.left != null) stack.push(node.left);
					if (node.right != null) stack.push(node.right);
				}
			}
		}
		trace("examined: " + cnt);
		return res;
	}
	
	/** Gets the next available id for a node, fecthing it from the list of unused ones if available. */
	private function getNextId():Int 
	{
		var newId = unusedIds.length > 0 ? unusedIds.pop() : maxId++;
		return newId;
	}
	
	/** Returns the node with the specified `id` to the pool. Note that it does NOT decrement `numNodes`. */
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
	
	/*
	 *           A			parent
	 *         /   \
	 *        B     C		left and right nodes
	 *       / \
	 *      D   E
	 */
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
	
	private function getNode(id:Int):AABBTreeNode<T> 
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
			assert(leaves.indexOf(node.id) != -1);
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