package ;

import AABBTreeNode;

enum InsertChoice {
	PARENT;			// choose parent as sibling node
	DESCEND_LEFT;	// descend left branch of the tree
	DESCEND_RIGHT;	// descent right branch of the tree
}

/**
 * Interface for strategies to apply when inserting a new leaf.
 * 
 * @author azrafe7
 */
interface IInsertStrategy<T>
{
	/** Choose which behaviour to apply in insert context. */
	public function choose<T>(leafAABB:AABB, parent:AABBTreeNode<T>, ?extraData:Dynamic):InsertChoice;
}