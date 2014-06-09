package;


import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.KeyboardEvent;
import flash.filters.GlowFilter;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.Lib;
import flash.system.System;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import haxe.Log;
import haxe.PosInfos;

@:access(AABBTree)
@:access(AABBTreeNode)
class Test extends Sprite {

	private var TEXT_COLOR:Int = 0xFFFFFFFF;
	private var TEXT_FONT:String = "_typewriter";
	private var TEXT_SIZE:Float = 12;
	private var TEXT_OFFSET:Float = -50;
	private var TEXT_OUTLINE:GlowFilter = new GlowFilter(0xFF000000, 1, 4, 4, 6);

	private var text:TextField;
	private var g:Graphics;
	private var invHeight:Int = 0;
	private var tree:AABBTree<Rectangle>;

	public function new () {
		super ();

		g = graphics;

		var r = new Rectangle();
		var p = new Point();
		
		//stage.addChild(new FPS(5, 5, 0xFFFFFF));
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		
		
		tree = new AABBTree(10);
		
		/*rtree.insert(1, new Rectangle());
		rtree.insert(2, new Rectangle(0,0,10,10));
		rtree.insert(3, new Rectangle(0,20,10,10));
		rtree.insert(4, new Rectangle(30, 0, 10, 10));
		
		*/
		for (i in 0...1) {
			var r = new Rectangle(Math.random() * 400 + 25, Math.random() * 300 + 25, Math.random() * 300 + 200, Math.random() * 150 + 50);
			//trace(r);
			tree.insertLeaf(r.x, r.y, r.width, r.height, r);
		}
		
		tree.insertLeaf(100, 100, 0, 0, new Rectangle());
		
		trace(tree.numNodes, tree.root.invHeight);
		drawTree(tree, 0);
		//trace(Math.random() * 100 + 200);
		
		stage.addChild(text = getTextField("invHeight: " + tree.root.invHeight, 50, 50));
		//quit();
	}

	
	public function drawTree<T>(tree:AABBTree<T>, invHeight:Int=0):Void 
	{
		var stack = [tree.root];
		var count = 0;
		while (stack.length > 0) {
			var node = stack.pop();
			count++;
			if (node.invHeight < invHeight) continue;
			var nodeColor = Std.int(Math.random() * 0xffffff);
			if (colors.length < node.invHeight) colors[node.invHeight] = Std.int(Math.random() * 0xffffff);
			nodeColor = colors[node.invHeight];
			if (!node.isLeaf()) {
				stack.push(node.left);
				stack.push(node.right);
				g.lineStyle(3, nodeColor, .7);
				g.drawRect(node.aabb.minX, node.aabb.minY, node.aabb.maxX - node.aabb.minX, node.aabb.maxY - node.aabb.minY);
			} else {
				g.lineStyle(0, nodeColor, .0);
				g.beginFill(nodeColor, .5);
				g.drawRect(node.aabb.minX, node.aabb.minY, node.aabb.maxX - node.aabb.minX, node.aabb.maxY - node.aabb.minY);
				g.endFill();
			}
			if (node.parent != null) {
				//var center = node.aabb.getCenter();
				g.lineStyle(1, Std.int(Math.random()*0xffffff));
				g.moveTo(node.aabb.minX, node.aabb.minY);
				g.lineTo(node.parent.aabb.minX, node.parent.aabb.minY);
			}
		}
		trace("nodes: " + count);
	}
	
	public function getTextField(text:String = "", x:Float, y:Float):TextField
	{
		var tf:TextField = new TextField();
		var fmt:TextFormat = new TextFormat(TEXT_FONT, null, TEXT_COLOR);
		tf.autoSize = TextFieldAutoSize.LEFT;
		fmt.align = TextFormatAlign.CENTER;
		fmt.size = TEXT_SIZE;
		tf.defaultTextFormat = fmt;
		tf.selectable = false;
		tf.x = x;
		tf.y = y + TEXT_OFFSET;
		tf.filters = [TEXT_OUTLINE];
		tf.text = text;
		return tf;
	}
	
	public function drawRects(list:Array<Rectangle>):Void 
	{
		for (r in list) {
			g.lineStyle(1, 0xffff00, .7);
			g.beginFill(0xffff00, .7);
			g.drawRect(r.x, r.y, r.width, r.height);
			g.endFill();
		}
	}

	public function onKeyDown(e:KeyboardEvent):Void 
	{
		if (e.keyCode == 27) quit();
		
		if (e.keyCode == UP || e.keyCode == DOWN) {
			g.clear();
			invHeight += e.keyCode == UP ? 1 : -1;
			if (invHeight < 0) invHeight = 0;
			drawTree(tree, invHeight);
		}
		
		else if (e.keyCode == "A".code) {
			var r = new Rectangle(Math.random() * 350 + 25, Math.random() * 300 + 25, Math.random() * 100 + 10, Math.random() * 100 + 10);
			tree.insertLeaf(r.x, r.y, r.width, r.height, r);
			g.clear();
			drawTree(tree, invHeight);
		}

		else if (e.keyCode == "Q".code) {
			g.clear();
			drawTree(tree, invHeight);
			var r = new Rectangle(Math.random() * 300 + 25, Math.random() * 300 + 25, Math.random() * 200 + 200, Math.random() * 150 + 50);
			g.lineStyle(1, -1);
			var qRect = new Rectangle(Math.random() * 100 + 200, Math.random() * 100 + 100, 2, 2);
			drawRects(tree.query(qRect.x, qRect.y, qRect.width, qRect.height));
			trace("leaves: " + tree.numLeaves);
			trace("found: " + tree.query(qRect.x, qRect.y, qRect.width, qRect.height).length);
			trace("balance: " + tree.getMaxBalance());
			g.drawRect(qRect.x, qRect.y, qRect.width, qRect.height);
		}
		var mem = System.totalMemory / 1024 / 1024;
		text.text = "mem: " + (Math.pow(mem, 10) / 100) + "  height: " + tree.root.invHeight;
	}
	
	public function quit():Void 
	{
		#if (flash || html5)
			System.exit(1);
		#else
			Sys.exit(1);
		#end
	}
	
	var colors = [0x808080, 0xff0000, 0x00ff00, 0x0000ff, 0xffffff];
	inline static var LEFT:Int = 37;
	inline static var UP:Int = 38;
	inline static var RIGHT:Int = 39;
	inline static var DOWN:Int = 40;
}