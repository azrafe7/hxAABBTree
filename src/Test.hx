package;


import ds.AABBTree;
import ds.aabbtree.InsertStrategyArea;
import ds.aabbtree.DebugRenderer;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
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
import haxe.Timer;
import openfl.display.FPS;



@:access(ds.AABBTree)
@:access(ds.aabbtree.Node)
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

	private var movingRectId:Int;
	private var movingRect:Rectangle = new Rectangle(100, 100, 100, 100);
	private var speed:Point = new Point(2, 2);
	
	private var startPoint:Point = new Point();
	private var endPoint:Point = new Point();
	
	public function new () {
		super ();

		g = graphics;

		var r = new Rectangle();
		var p = new Point();
		
		stage.addChild(new FPS(5, 5, 0xFFFFFF));
		stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		
		
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
		
		tree.insertLeaf(100, 100, 0, 0, new Rectangle(100, 100, 0, 0));
		
		tree.rebuild();
		
		movingRectId = tree.insertLeaf(movingRect.x, movingRect.y, movingRect.width, movingRect.height, movingRect);
		
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
		//trace("nodes: " + count);
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
			if (r.width < .5 && r.height < .5) {
				g.drawCircle(r.x, r.y, 2);
			} else {
				g.beginFill(0xffff00, .7);
				g.drawRect(r.x, r.y, r.width, r.height);
				g.endFill();
			}
		}
	}
	
	public function rayCallback(data:Rectangle, id:Int):HitBehaviour
	{
		if (data.width < 30 && data.height < 30) return HitBehaviour.SKIP;
		return HitBehaviour.INCLUDE;
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
		
		else if (e.keyCode == "R".code) {
			tree.rebuild();
			g.lineStyle(1, -1);
			var qRect = lastQRect;
			drawRects(tree.query(qRect.x, qRect.y, qRect.width, qRect.height));
			trace("leaves: " + tree.numLeaves + "/" + tree.numNodes);
			trace("found: " + tree.query(qRect.x, qRect.y, qRect.width, qRect.height).length);
			trace("balance: " + tree.getMaxBalance());
			if (qRect.width > 0) g.drawRect(qRect.x, qRect.y, qRect.width, qRect.height);
			else g.drawCircle(qRect.x, qRect.y, 2);
		}
		
		else if (e.keyCode == "A".code) {
			var r = new Rectangle(Math.random() * 350 + 25, Math.random() * 300 + 25, Math.random() * 100 + 10, Math.random() * 100 + 10);
			tree.insertLeaf(r.x, r.y, r.width, r.height, r);
			g.clear();
			drawTree(tree, invHeight);
		}

		
		if (e.keyCode == "Q".code) {
			g.clear();
			drawTree(tree, invHeight);
			g.lineStyle(1, -1);
			//var qRect = new Rectangle(Math.random() * 300 + 25, Math.random() * 200 + 25, 0, 0);
			var tmp:Float;
			if (endPoint.x < startPoint.x) {
				tmp = endPoint.x;
				endPoint.x = startPoint.x;
				startPoint.x = tmp;
			}
			if (endPoint.y < startPoint.y) {
				tmp = endPoint.y;
				endPoint.y = startPoint.y;
				startPoint.y = tmp;
			}
			var qRect = new Rectangle(startPoint.x, startPoint.y, endPoint.x - startPoint.x, endPoint.y - startPoint.y);
			var start = Timer.stamp();
			var contain = true;
			drawRects(tree.query(qRect.x, qRect.y, qRect.width, qRect.height, contain));
			trace("time: " + (Timer.stamp() - start));
			trace("leaves: " + tree.numLeaves + "/" + tree.numNodes);
			trace("found: " + tree.query(qRect.x, qRect.y, qRect.width, qRect.height, contain).length);
			trace("balance: " + tree.getMaxBalance());
			if (qRect.width > 0 || qRect.height > 0) g.drawRect(qRect.x, qRect.y, qRect.width, qRect.height);
			else g.drawCircle(qRect.x, qRect.y, 2);
			lastQRect = qRect;
		}
		
		if (e.keyCode == "C".code) {
			g.clear();
			drawTree(tree, invHeight);
			g.lineStyle(1, -1);
			var qRect = new Rectangle(Math.random() * stage.stageWidth, Math.random() * stage.stageHeight, Math.random() * stage.stageWidth, Math.random() * stage.stageHeight);
			var start = Timer.stamp();
			drawRects(tree.rayCast(startPoint.x, startPoint.y, endPoint.x, endPoint.y, rayCallback));
			trace("time: " + (Timer.stamp() - start));
			trace("leaves: " + tree.numLeaves + "/" + tree.numNodes);
			trace("found: " + tree.rayCast(startPoint.x, startPoint.y, endPoint.x, endPoint.y, rayCallback).length);
			trace("balance: " + tree.getMaxBalance());
			g.moveTo(startPoint.x, startPoint.y);
			g.lineTo(endPoint.x, endPoint.y);
		}
		
		var mem = System.totalMemory / 1024 / 1024;
		text.text = "mem: " + (Std.int(mem * 100) / 100) + "  height: " + tree.root.invHeight;
	}
	
	public function onEnterFrame(_):Void 
	{
		if (Math.random() < .7) {
			movingRect.width += Math.cos(Math.random() * Math.PI * 60);
			movingRect.height += Math.cos(Math.random() * Math.PI * 60);
		}
		
		movingRect.x += speed.x;
		movingRect.y += speed.y;
		if (movingRect.x < 0) {
			movingRect.x = 0;
			speed.x *= -1;
		} else if (movingRect.x + movingRect.width > stage.stageWidth) {
			movingRect.x = stage.stageWidth - movingRect.width;
			speed.x *= -1;
		} 
		if (movingRect.y < 0) {
			movingRect.y = 0;
			speed.y *= -1;
		} else if (movingRect.y + movingRect.height > stage.stageHeight) {
			movingRect.y = stage.stageHeight - movingRect.height;
			speed.y *= -1;
		} 

		tree.updateLeaf(movingRectId, movingRect.x, movingRect.y, movingRect.width, movingRect.height);
		//g.clear();
		//drawTree(tree, invHeight);
	}
	
	public function onMouseDown(e:MouseEvent):Void 
	{
		startPoint.x = e.stageX;
		startPoint.y = e.stageY;
	}
	
	public function onMouseUp(e:MouseEvent):Void 
	{
		endPoint.x = e.stageX;
		endPoint.y = e.stageY;
	}
	
	public function quit():Void 
	{
		#if (flash || html5)
			System.exit(1);
		#else
			Sys.exit(1);
		#end
	}

	var lastQRect:Rectangle = new Rectangle();
	var colors = [0x808080, 0xff0000, 0x00ff00, 0x0000ff, 0xffffff];
	inline static var LEFT:Int = 37;
	inline static var UP:Int = 38;
	inline static var RIGHT:Int = 39;
	inline static var DOWN:Int = 40;
}